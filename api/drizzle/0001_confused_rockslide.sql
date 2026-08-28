CREATE TABLE "chat" (
	"id" text PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "chat_message" (
	"id" text PRIMARY KEY NOT NULL,
	"chat_id" text NOT NULL,
	"position" integer NOT NULL,
	"message" text NOT NULL,
	"reasoning_duration_seconds" double precision,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "chat" ADD CONSTRAINT "chat_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "chat_message" ADD CONSTRAINT "chat_message_chat_id_chat_id_fk" FOREIGN KEY ("chat_id") REFERENCES "public"."chat"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "chat_userId_idx" ON "chat" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "chat_message_chatId_idx" ON "chat_message" USING btree ("chat_id");--> statement-breakpoint
CREATE UNIQUE INDEX "chat_message_chatId_position_idx" ON "chat_message" USING btree ("chat_id","position");
