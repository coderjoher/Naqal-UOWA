-- CreateEnum
CREATE TYPE "TaxiDirection" AS ENUM ('to_campus', 'from_campus');

-- CreateEnum
CREATE TYPE "TaxiRideStatus" AS ENUM ('requested', 'accepted', 'arrived', 'on_trip', 'done', 'cancelled', 'expired');

-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "taxi_ride_id" UUID;

-- AlterTable
ALTER TABLE "universities" ADD COLUMN     "taxi_base_fare" INTEGER NOT NULL DEFAULT 2000,
ADD COLUMN     "taxi_enabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "taxi_min_fare" INTEGER NOT NULL DEFAULT 3000,
ADD COLUMN     "taxi_offer_seconds" INTEGER NOT NULL DEFAULT 180,
ADD COLUMN     "taxi_per_km" INTEGER NOT NULL DEFAULT 500;

-- CreateTable
CREATE TABLE "taxi_rides" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "driver_id" UUID,
    "direction" "TaxiDirection" NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "label" TEXT,
    "distance_km" DOUBLE PRECISION NOT NULL,
    "fare" INTEGER NOT NULL,
    "status" "TaxiRideStatus" NOT NULL DEFAULT 'requested',
    "client_id" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "accepted_at" TIMESTAMP(3),
    "arrived_at" TIMESTAMP(3),
    "started_at" TIMESTAMP(3),
    "ended_at" TIMESTAMP(3),
    "cancelled_at" TIMESTAMP(3),
    "cancelled_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "taxi_rides_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "taxi_rides_client_id_key" ON "taxi_rides"("client_id");

-- CreateIndex
CREATE INDEX "taxi_rides_university_id_status_created_at_idx" ON "taxi_rides"("university_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "taxi_rides_student_id_created_at_idx" ON "taxi_rides"("student_id", "created_at");

-- CreateIndex
CREATE INDEX "taxi_rides_driver_id_created_at_idx" ON "taxi_rides"("driver_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "payments_taxi_ride_id_key" ON "payments"("taxi_ride_id");

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_taxi_ride_id_fkey" FOREIGN KEY ("taxi_ride_id") REFERENCES "taxi_rides"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "taxi_rides" ADD CONSTRAINT "taxi_rides_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "taxi_rides" ADD CONSTRAINT "taxi_rides_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "taxi_rides" ADD CONSTRAINT "taxi_rides_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

