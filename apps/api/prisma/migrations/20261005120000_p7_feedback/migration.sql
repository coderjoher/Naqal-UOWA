-- CreateEnum
CREATE TYPE "ProblemStatus" AS ENUM ('open', 'resolved');

-- CreateTable
CREATE TABLE "ride_ratings" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "request_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "driver_id" UUID NOT NULL,
    "run_id" UUID NOT NULL,
    "stars" INTEGER NOT NULL,
    "comment" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ride_ratings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "problem_reports" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "request_id" UUID,
    "category" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "status" "ProblemStatus" NOT NULL DEFAULT 'open',
    "reply" TEXT,
    "resolved_by_id" UUID,
    "resolved_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "problem_reports_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "announcements" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "target" TEXT NOT NULL,
    "wave_id" UUID,
    "date" DATE,
    "point_id" UUID,
    "recipients" INTEGER NOT NULL,
    "created_by_id" UUID NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "announcements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ride_ratings_request_id_key" ON "ride_ratings"("request_id");

-- CreateIndex
CREATE INDEX "ride_ratings_university_id_created_at_idx" ON "ride_ratings"("university_id", "created_at");

-- CreateIndex
CREATE INDEX "ride_ratings_driver_id_idx" ON "ride_ratings"("driver_id");

-- CreateIndex
CREATE INDEX "problem_reports_university_id_status_created_at_idx" ON "problem_reports"("university_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "announcements_university_id_created_at_idx" ON "announcements"("university_id", "created_at");

-- AddForeignKey
ALTER TABLE "ride_ratings" ADD CONSTRAINT "ride_ratings_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_ratings" ADD CONSTRAINT "ride_ratings_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_ratings" ADD CONSTRAINT "ride_ratings_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "problem_reports" ADD CONSTRAINT "problem_reports_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "problem_reports" ADD CONSTRAINT "problem_reports_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "announcements" ADD CONSTRAINT "announcements_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

