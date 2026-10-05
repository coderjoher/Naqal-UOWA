-- CreateEnum
CREATE TYPE "SettlementStatus" AS ENUM ('draft', 'approved');

-- AlterTable
ALTER TABLE "runs" ADD COLUMN     "gps_flags" JSONB NOT NULL DEFAULT '[]',
ADD COLUMN     "gps_verified" BOOLEAN,
ADD COLUMN     "office_note" TEXT,
ADD COLUMN     "office_verdict" BOOLEAN;

-- CreateTable
CREATE TABLE "settlements" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "month" TEXT NOT NULL,
    "status" "SettlementStatus" NOT NULL DEFAULT 'draft',
    "commission_bp" INTEGER NOT NULL,
    "tiers" JSONB NOT NULL DEFAULT '[]',
    "total_pool" BIGINT NOT NULL,
    "total_payout" BIGINT NOT NULL,
    "total_commission" BIGINT NOT NULL,
    "total_cash" BIGINT NOT NULL,
    "unallocated" BIGINT NOT NULL,
    "rounding_residual" BIGINT NOT NULL,
    "excluded_runs" INTEGER NOT NULL,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "approved_at" TIMESTAMP(3),
    "approved_by_id" UUID,

    CONSTRAINT "settlements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "settlement_lines" (
    "id" UUID NOT NULL,
    "university_id" UUID NOT NULL,
    "settlement_id" UUID NOT NULL,
    "driver_id" UUID NOT NULL,
    "runs" INTEGER NOT NULL,
    "tiers" JSONB NOT NULL DEFAULT '[]',
    "cash" BIGINT NOT NULL,
    "cash_commission" BIGINT NOT NULL,
    "payout" BIGINT NOT NULL,

    CONSTRAINT "settlement_lines_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "settlements_university_id_month_key" ON "settlements"("university_id", "month");

-- CreateIndex
CREATE UNIQUE INDEX "settlement_lines_settlement_id_driver_id_key" ON "settlement_lines"("settlement_id", "driver_id");

-- AddForeignKey
ALTER TABLE "settlements" ADD CONSTRAINT "settlements_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "settlement_lines" ADD CONSTRAINT "settlement_lines_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "settlement_lines" ADD CONSTRAINT "settlement_lines_settlement_id_fkey" FOREIGN KEY ("settlement_id") REFERENCES "settlements"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "settlement_lines" ADD CONSTRAINT "settlement_lines_driver_id_fkey" FOREIGN KEY ("driver_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;


-- NF-14 / T6-04: an approved settlement and its lines can never change or be deleted.
CREATE OR REPLACE FUNCTION forbid_approved_settlement_change() RETURNS trigger AS $$
BEGIN
  IF OLD.status = 'approved' THEN
    RAISE EXCEPTION 'Approved settlements are immutable'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER settlements_immutable_when_approved
  BEFORE UPDATE OR DELETE ON "settlements"
  FOR EACH ROW EXECUTE FUNCTION forbid_approved_settlement_change();

CREATE OR REPLACE FUNCTION forbid_approved_line_change() RETURNS trigger AS $$
DECLARE s "SettlementStatus";
BEGIN
  SELECT status INTO s FROM "settlements" WHERE id = COALESCE(OLD.settlement_id, NEW.settlement_id);
  IF s = 'approved' THEN
    RAISE EXCEPTION 'Approved settlements are immutable'
      USING ERRCODE = 'integrity_constraint_violation';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER settlement_lines_immutable_when_approved
  BEFORE INSERT OR UPDATE OR DELETE ON "settlement_lines"
  FOR EACH ROW EXECUTE FUNCTION forbid_approved_line_change();
