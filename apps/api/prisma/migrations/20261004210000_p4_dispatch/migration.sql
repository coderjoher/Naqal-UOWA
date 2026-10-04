-- CreateEnum
CREATE TYPE "RideStatus" AS ENUM ('open', 'assigned', 'waitlisted', 'cancelled', 'done');

-- CreateEnum
CREATE TYPE "RunStatus" AS ENUM ('planned', 'started', 'done', 'cancelled');

-- CreateTable
CREATE TABLE "driver_availability" (
    "university_id" UUID NOT NULL,
    "driver_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "wave_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_availability_pkey" PRIMARY KEY ("driver_id","date","wave_id")
);

-- CreateTable
CREATE TABLE "ride_requests" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "wave_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "point_id" UUID NOT NULL,
    "tier_id" UUID NOT NULL,
    "gender" "Gender" NOT NULL,
    "subscriber" BOOLEAN NOT NULL,
    "fare" INTEGER NOT NULL,
    "status" "RideStatus" NOT NULL DEFAULT 'open',
    "run_id" UUID,
    "waitlisted_until" TIMESTAMP(3),
    "cancel_reason" TEXT,
    "boarded_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ride_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "runs" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "driver_id" UUID NOT NULL,
    "wave_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "gender" "Gender" NOT NULL,
    "tier_id" UUID NOT NULL,
    "capacity" INTEGER NOT NULL,
    "status" "RunStatus" NOT NULL DEFAULT 'planned',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "runs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "run_stops" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "run_id" UUID NOT NULL,
    "seq" INTEGER NOT NULL,
    "point_id" UUID NOT NULL,
    "eta" TIMESTAMP(3) NOT NULL,
    "served_at" TIMESTAMP(3),

    CONSTRAINT "run_stops_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wave_plans" (
    "university_id" UUID NOT NULL,
    "wave_id" UUID NOT NULL,
    "date" DATE NOT NULL,
    "planned_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wave_plans_pkey" PRIMARY KEY ("wave_id","date")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kind" TEXT NOT NULL,
    "data" JSONB NOT NULL DEFAULT '{}',
    "read_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "driver_availability_university_id_date_wave_id_idx" ON "driver_availability"("university_id", "date", "wave_id");

-- CreateIndex
CREATE INDEX "ride_requests_university_id_date_wave_id_status_idx" ON "ride_requests"("university_id", "date", "wave_id", "status");

-- CreateIndex
CREATE INDEX "ride_requests_student_id_date_idx" ON "ride_requests"("student_id", "date");

-- CreateIndex
CREATE INDEX "runs_university_id_date_wave_id_idx" ON "runs"("university_id", "date", "wave_id");

-- CreateIndex
CREATE UNIQUE INDEX "runs_driver_id_wave_id_date_key" ON "runs"("driver_id", "wave_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "run_stops_run_id_seq_key" ON "run_stops"("run_id", "seq");

-- CreateIndex
CREATE INDEX "notifications_user_id_created_at_idx" ON "notifications"("user_id", "created_at");

-- AddForeignKey
ALTER TABLE "driver_availability" ADD CONSTRAINT "driver_availability_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_availability" ADD CONSTRAINT "driver_availability_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_availability" ADD CONSTRAINT "driver_availability_wave_id_fkey" FOREIGN KEY ("wave_id") REFERENCES "waves"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_requests" ADD CONSTRAINT "ride_requests_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_requests" ADD CONSTRAINT "ride_requests_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_requests" ADD CONSTRAINT "ride_requests_wave_id_fkey" FOREIGN KEY ("wave_id") REFERENCES "waves"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_requests" ADD CONSTRAINT "ride_requests_point_id_fkey" FOREIGN KEY ("point_id") REFERENCES "gathering_points"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ride_requests" ADD CONSTRAINT "ride_requests_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "runs"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "runs" ADD CONSTRAINT "runs_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "runs" ADD CONSTRAINT "runs_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "runs" ADD CONSTRAINT "runs_wave_id_fkey" FOREIGN KEY ("wave_id") REFERENCES "waves"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "run_stops" ADD CONSTRAINT "run_stops_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "run_stops" ADD CONSTRAINT "run_stops_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "runs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "run_stops" ADD CONSTRAINT "run_stops_point_id_fkey" FOREIGN KEY ("point_id") REFERENCES "gathering_points"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wave_plans" ADD CONSTRAINT "wave_plans_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wave_plans" ADD CONSTRAINT "wave_plans_wave_id_fkey" FOREIGN KEY ("wave_id") REFERENCES "waves"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- One live request per student, wave and date (ST-04).
CREATE UNIQUE INDEX "ride_requests_one_live" ON "ride_requests" ("student_id", "wave_id", "date") WHERE "status" IN ('open', 'assigned', 'waitlisted');
