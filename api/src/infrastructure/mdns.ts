// mdns: project logic for this module.
import dgram from "node:dgram";
import os from "node:os";

const multicastAddress = "224.0.0.251";
const multicastPort = 5353;
const serviceType = "_sarvam-api._tcp.local";
const serviceName = "Sarvam API";

// Defines encodeName.
function encodeName(name: string): Buffer {
  const labels = name.split(".");
  const parts = labels.map((label) => {
    const value = Buffer.from(label);
    return Buffer.concat([Buffer.from([value.length]), value]);
  });
  return Buffer.concat([...parts, Buffer.from([0])]);
}

// Defines uint16.
function uint16(value: number): Buffer {
  const buffer = Buffer.alloc(2);
  buffer.writeUInt16BE(value);
  return buffer;
}

// Defines uint32.
function uint32(value: number): Buffer {
  const buffer = Buffer.alloc(4);
  buffer.writeUInt32BE(value);
  return buffer;
}

// Defines record.
function record(name: string, type: number, ttl: number, data: Buffer): Buffer {
  return Buffer.concat([
    encodeName(name),
    uint16(type),
    uint16(1),
    uint32(ttl),
    uint16(data.length),
    data,
  ]);
}

// Defines localIPv4Address.
function localIPv4Address(): string | undefined {
  for (const interfaces of Object.values(os.networkInterfaces())) {
    for (const networkInterface of interfaces ?? []) {
      if (networkInterface.family === "IPv4" && !networkInterface.internal) {
        return networkInterface.address;
      }
    }
  }
  return undefined;
}

// Defines announcement.
function announcement(port: number): Buffer {
  const instance = `${serviceName}.${serviceType}`;
  const hostname = `${os.hostname().split(".")[0]}.local`;
  const address = localIPv4Address();

  const answers = [
    record(serviceType, 12, 120, encodeName(instance)),
    record(
      instance,
      33,
      120,
      Buffer.concat([uint16(0), uint16(0), uint16(port), encodeName(hostname)]),
    ),
    record(instance, 16, 120, Buffer.from([0])),
  ];

  if (address) {
    const octets = address.split(".").map(Number);
    answers.push(record(hostname, 1, 120, Buffer.from(octets)));
  }

  return Buffer.concat([
    uint16(0),
    uint16(0x8400),
    uint16(0),
    uint16(answers.length),
    uint16(0),
    uint16(0),
    ...answers,
  ]);
}

// Exports startMDNSBroadcast.
export function startMDNSBroadcast(port: number): () => void {
  const socket = dgram.createSocket({ type: "udp4", reuseAddr: true });
  const packet = announcement(port);
  let isClosed = false;
  const announcementInterval = setInterval(() => {
    if (!isClosed) {
      socket.send(packet, multicastPort, multicastAddress);
    }
  }, 30_000);

  socket.on("error", (error) => {
    console.error("[API:mDNS] Broadcast failed", error);
    isClosed = true;
    clearInterval(announcementInterval);
  });

  socket.bind(multicastPort, () => {
    socket.setMulticastTTL(255);
    socket.addMembership(multicastAddress);
    socket.send(packet, multicastPort, multicastAddress);
    console.log(`[API:mDNS] Broadcasting on port ${port}`);
  });

  socket.on("message", (message) => {
    // DNS-SD browsers send a standard query (QR = 0). Respond with the
    // complete service record set so late-starting clients can discover us.
    if (message.length >= 4 && (message.readUInt16BE(2) & 0x8000) === 0) {
      socket.send(packet, multicastPort, multicastAddress);
    }
  });

  return () => {
    if (isClosed) return;
    isClosed = true;
    clearInterval(announcementInterval);
    socket.close();
    console.log("[API:mDNS] Broadcast stopped");
  };
}
