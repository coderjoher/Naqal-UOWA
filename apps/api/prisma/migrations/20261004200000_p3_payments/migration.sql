-- CreateEnum
CREATE TYPE "PaymentType" AS ENUM ('subscription', 'cash_fare', 'tier_difference');

-- CreateEnum
CREATE TYPE "PaymentMethod" AS ENUM ('cash_office', 'cash_driver', 'zaincash', 'qi');

-- CreateEnum
CREATE TYPE "SubscriptionStatus" AS ENUM ('active', 'cancelled');

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "type" "PaymentType" NOT NULL,
    "method" "PaymentMethod" NOT NULL,
    "amount" INTEGER NOT NULL,
    "receipt_no" INTEGER NOT NULL,
    "student_id" UUID,
    "collected_by_id" UUID NOT NULL,
    "external_ref" TEXT,
    "reverses_payment_id" UUID,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "subscriptions" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "student_id" UUID NOT NULL,
    "tier_id" UUID NOT NULL,
    "point_id" UUID NOT NULL,
    "month" TEXT NOT NULL,
    "period_start" DATE NOT NULL,
    "period_end" DATE NOT NULL,
    "price" INTEGER NOT NULL,
    "status" "SubscriptionStatus" NOT NULL DEFAULT 'active',
    "payment_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "receipt_counters" (
    "university_id" UUID NOT NULL,
    "last" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "receipt_counters_pkey" PRIMARY KEY ("university_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "payments_reverses_payment_id_key" ON "payments"("reverses_payment_id");

-- CreateIndex
CREATE INDEX "payments_university_id_created_at_idx" ON "payments"("university_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "payments_university_id_receipt_no_key" ON "payments"("university_id", "receipt_no");

-- CreateIndex
CREATE UNIQUE INDEX "subscriptions_payment_id_key" ON "subscriptions"("payment_id");

-- CreateIndex
CREATE INDEX "subscriptions_university_id_month_idx" ON "subscriptions"("university_id", "month");

-- CreateIndex
CREATE INDEX "subscriptions_student_id_period_end_idx" ON "subscriptions"("student_id", "period_end");

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_reverses_payment_id_fkey" FOREIGN KEY ("reverses_payment_id") REFERENCES "payments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_student_id_fkey" FOREIGN KEY ("student_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "subscriptions" ADD CONSTRAINT "subscriptions_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "payments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "receipt_counters" ADD CONSTRAINT "receipt_counters_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- NF-14: money records are immutable. Corrections are reversal rows, never edits or deletes.
CREATE OR REPLACE FUNCTION forbid_money_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'Money records are immutable (%). Record a reversal instead.', TG_TABLE_NAME
    USING ERRCODE = 'integrity_constraint_violation';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payments_immutable
  BEFORE UPDATE OR DELETE ON "payments"
  FOR EACH ROW EXECUTE FUNCTION forbid_money_mutation();

-- TRUNCATE is allowed only for test resets (statement-level trigger not added on purpose).
