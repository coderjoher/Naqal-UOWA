-- CreateEnum
CREATE TYPE "WaveType" AS ENUM ('morning', 'return');

-- AlterTable
ALTER TABLE "universities" ADD COLUMN     "coverage" JSONB NOT NULL DEFAULT '[]';

-- CreateTable
CREATE TABLE "distance_tiers" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "min_km" DOUBLE PRECISION NOT NULL,
    "max_km" DOUBLE PRECISION,
    "subscription_price" INTEGER NOT NULL,
    "ride_price" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "distance_tiers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "gathering_points" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "name_ar" TEXT,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "tier_id" UUID NOT NULL,
    "tier_overridden" BOOLEAN NOT NULL DEFAULT false,
    "distance_km" DOUBLE PRECISION,
    "duration_min" DOUBLE PRECISION,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "gathering_points_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "waves" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "type" "WaveType" NOT NULL,
    "minute_of_day" INTEGER NOT NULL,
    "weekdays" INTEGER NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "waves_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_requirement_sets" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "documents" JSONB NOT NULL DEFAULT '[]',
    "vehicle_types" JSONB NOT NULL DEFAULT '[]',
    "min_seats" INTEGER NOT NULL DEFAULT 10,
    "max_vehicle_age_years" INTEGER NOT NULL DEFAULT 15,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "driver_requirement_sets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "travel_times" (
    "university_id" UUID NOT NULL,
    "from_key" TEXT NOT NULL,
    "to_key" TEXT NOT NULL,
    "duration_s" INTEGER NOT NULL,
    "distance_m" INTEGER NOT NULL,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "travel_times_pkey" PRIMARY KEY ("university_id","from_key","to_key")
);

-- CreateIndex
CREATE INDEX "distance_tiers_university_id_min_km_idx" ON "distance_tiers"("university_id", "min_km");

-- CreateIndex
CREATE INDEX "gathering_points_university_id_active_idx" ON "gathering_points"("university_id", "active");

-- CreateIndex
CREATE INDEX "waves_university_id_type_idx" ON "waves"("university_id", "type");

-- CreateIndex
CREATE UNIQUE INDEX "driver_requirement_sets_university_id_key" ON "driver_requirement_sets"("university_id");

-- AddForeignKey
ALTER TABLE "distance_tiers" ADD CONSTRAINT "distance_tiers_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gathering_points" ADD CONSTRAINT "gathering_points_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "gathering_points" ADD CONSTRAINT "gathering_points_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "distance_tiers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "waves" ADD CONSTRAINT "waves_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_requirement_sets" ADD CONSTRAINT "driver_requirement_sets_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "travel_times" ADD CONSTRAINT "travel_times_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
