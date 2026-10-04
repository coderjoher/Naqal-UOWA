-- CreateEnum
CREATE TYPE "DriverStatus" AS ENUM ('draft', 'pending', 'approved', 'rejected', 'suspended');

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "default_point_id" UUID,
ADD COLUMN     "login_phone" TEXT,
ADD COLUMN     "name_ar" TEXT,
ADD COLUMN     "student_id" TEXT;

-- CreateTable
CREATE TABLE "roster_entries" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "student_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "name_ar" TEXT,
    "gender" "Gender" NOT NULL,
    "activation_code_hash" TEXT,
    "activation_expires_at" TIMESTAMP(3),
    "activation_attempts" INTEGER NOT NULL DEFAULT 0,
    "activated_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "roster_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "driver_profiles" (
    "user_id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "status" "DriverStatus" NOT NULL DEFAULT 'draft',
    "vehicle_type" TEXT,
    "plate" TEXT,
    "seats" INTEGER,
    "model_year" INTEGER,
    "submitted_at" TIMESTAMP(3),
    "reviewed_at" TIMESTAMP(3),
    "reviewed_by_id" UUID,
    "review_note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "driver_profiles_pkey" PRIMARY KEY ("user_id")
);

-- CreateTable
CREATE TABLE "driver_documents" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "driver_id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "storage_key" TEXT NOT NULL,
    "mime" TEXT NOT NULL,
    "size_bytes" INTEGER NOT NULL,
    "uploaded_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "driver_documents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "document_accesses" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "document_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "document_accesses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "otp_codes" (
    "phone" TEXT NOT NULL,
    "code_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "otp_codes_pkey" PRIMARY KEY ("phone")
);

-- CreateIndex
CREATE UNIQUE INDEX "roster_entries_university_id_student_id_key" ON "roster_entries"("university_id", "student_id");

-- CreateIndex
CREATE INDEX "driver_profiles_university_id_status_idx" ON "driver_profiles"("university_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "driver_documents_driver_id_key_key" ON "driver_documents"("driver_id", "key");

-- CreateIndex
CREATE INDEX "document_accesses_university_id_document_id_idx" ON "document_accesses"("university_id", "document_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_login_phone_key" ON "users"("login_phone");

-- CreateIndex
CREATE UNIQUE INDEX "users_university_id_student_id_key" ON "users"("university_id", "student_id");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_default_point_id_fkey" FOREIGN KEY ("default_point_id") REFERENCES "gathering_points"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "roster_entries" ADD CONSTRAINT "roster_entries_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_profiles" ADD CONSTRAINT "driver_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_profiles" ADD CONSTRAINT "driver_profiles_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_documents" ADD CONSTRAINT "driver_documents_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "driver_documents" ADD CONSTRAINT "driver_documents_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "driver_profiles"("user_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "document_accesses" ADD CONSTRAINT "document_accesses_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "document_accesses" ADD CONSTRAINT "document_accesses_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "driver_documents"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

