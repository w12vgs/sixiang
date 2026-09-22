-- 四象后端初始化 DDL（与 prisma/schema.prisma 保持一致）
-- 用途：无 Docker / 无 prisma CLI 环境下（如本机冒烟测试）建表。
-- 生产/CI 环境请使用 `npx prisma db push`（以 schema.prisma 为准）。

CREATE TABLE "users" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "email" text NOT NULL,
  "password_hash" text NOT NULL,
  "display_name" text,
  "created_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

CREATE TABLE "tasks" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "title" text NOT NULL,
  "note" text,
  "quadrant" integer NOT NULL DEFAULT 1,
  "priority" integer NOT NULL DEFAULT 2,
  "due_at" timestamp(3),
  "reminder_at" timestamp(3),
  "repeat_rule" text,
  "sort_order" integer NOT NULL DEFAULT 0,
  "completed_at" timestamp(3),
  "deleted_at" timestamp(3),
  "created_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "tasks_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "tasks_user_id_updated_at_idx" ON "tasks"("user_id", "updated_at");
CREATE INDEX "tasks_user_id_deleted_at_idx" ON "tasks"("user_id", "deleted_at");
ALTER TABLE "tasks" ADD CONSTRAINT "tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "subtasks" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "task_id" uuid NOT NULL,
  "title" text NOT NULL,
  "done" boolean NOT NULL DEFAULT false,
  "sort_order" integer NOT NULL DEFAULT 0,
  "created_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "subtasks_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "subtasks_task_id_idx" ON "subtasks"("task_id");
ALTER TABLE "subtasks" ADD CONSTRAINT "subtasks_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "events" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "title" text NOT NULL,
  "note" text,
  "location" text,
  "start_at" timestamp(3) NOT NULL,
  "end_at" timestamp(3) NOT NULL,
  "all_day" boolean NOT NULL DEFAULT false,
  "remind_offset_minutes" integer,
  "repeat_rule" text,
  "calendar_id" text,
  "deleted_at" timestamp(3),
  "created_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "events_user_id_updated_at_idx" ON "events"("user_id", "updated_at");
CREATE INDEX "events_user_id_deleted_at_idx" ON "events"("user_id", "deleted_at");
ALTER TABLE "events" ADD CONSTRAINT "events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "notes" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "title" text NOT NULL,
  "content" text NOT NULL DEFAULT '',
  "pinned" boolean NOT NULL DEFAULT false,
  "archived" boolean NOT NULL DEFAULT false,
  "deleted_at" timestamp(3),
  "created_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "notes_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "notes_user_id_updated_at_idx" ON "notes"("user_id", "updated_at");
CREATE INDEX "notes_user_id_deleted_at_idx" ON "notes"("user_id", "deleted_at");
ALTER TABLE "notes" ADD CONSTRAINT "notes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "tags" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "name" text NOT NULL,
  "color" text NOT NULL DEFAULT '#5E6AD2',
  "deleted_at" timestamp(3),
  "created_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "tags_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "tags_user_id_name_key" ON "tags"("user_id", "name");
CREATE INDEX "tags_user_id_updated_at_idx" ON "tags"("user_id", "updated_at");
ALTER TABLE "tags" ADD CONSTRAINT "tags_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "task_tags" (
  "task_id" uuid NOT NULL,
  "tag_id" uuid NOT NULL,
  CONSTRAINT "task_tags_pkey" PRIMARY KEY ("task_id", "tag_id")
);
ALTER TABLE "task_tags" ADD CONSTRAINT "task_tags_task_id_fkey" FOREIGN KEY ("task_id") REFERENCES "tasks"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "task_tags" ADD CONSTRAINT "task_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "tags"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "note_tags" (
  "note_id" uuid NOT NULL,
  "tag_id" uuid NOT NULL,
  CONSTRAINT "note_tags_pkey" PRIMARY KEY ("note_id", "tag_id")
);
ALTER TABLE "note_tags" ADD CONSTRAINT "note_tags_note_id_fkey" FOREIGN KEY ("note_id") REFERENCES "notes"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "note_tags" ADD CONSTRAINT "note_tags_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "tags"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "attachments" (
  "id" uuid NOT NULL DEFAULT gen_random_uuid(),
  "user_id" uuid NOT NULL,
  "file_name" text NOT NULL,
  "file_path" text NOT NULL,
  "mime_type" text,
  "size_bytes" integer NOT NULL,
  "note_id" uuid,
  "task_id" uuid,
  "created_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "attachments_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "attachments_user_id_created_at_idx" ON "attachments"("user_id", "created_at");
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "device_sync" (
  "user_id" uuid NOT NULL,
  "device_id" text NOT NULL,
  "last_synced_at" timestamp(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "device_sync_pkey" PRIMARY KEY ("user_id", "device_id")
);
ALTER TABLE "device_sync" ADD CONSTRAINT "device_sync_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
