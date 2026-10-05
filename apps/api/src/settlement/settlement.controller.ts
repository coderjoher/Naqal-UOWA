import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsString, MaxLength, ValidateIf } from 'class-validator';
import type { Response } from 'express';
import { AuditedByHandler } from '../audit/audit.interceptor';
import { AuditService } from '../audit/audit.service';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { monthOf } from '../subscriptions/period-policy';
import { tenantUniversityId } from '../tiers/tiers.service';
import { monthRange, SettlementService } from './settlement.service';

export class VerdictDto {
  @ApiPropertyOptional({ nullable: true, description: 'true: counts, false: excluded, null: follow the GPS check' })
  @ValidateIf((_, v) => v !== null)
  @IsBoolean()
  verdict!: boolean | null;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(300) note?: string;
}

const month = (m?: string) => {
  const v = m ?? monthOf(new Date());
  monthRange(v); // validates
  return v;
};

@ApiTags('settlement')
@ApiBearerAuth()
@Controller()
export class SettlementController {
  constructor(
    private readonly settlement: SettlementService,
    private readonly audit: AuditService,
  ) {}

  @Roles('office')
  @Get('settlements')
  list() {
    return this.settlement.list(tenantUniversityId());
  }

  /** TO-09: the month's settlement (null until computed). */
  @Roles('office')
  @Get('settlements/:month')
  async get(@Param('month') m: string) {
    return { settlement: await this.settlement.get(tenantUniversityId(), month(m)), review: await this.settlement.review(tenantUniversityId(), month(m)) };
  }

  @Roles('office')
  @Post('settlements/:month/compute')
  @HttpCode(200)
  compute(@Param('month') m: string) {
    return this.settlement.compute(tenantUniversityId(), month(m));
  }

  @Roles('office')
  @Post('settlements/:month/approve')
  @HttpCode(200)
  @AuditedByHandler()
  approve(@CurrentUser() u: AuthUser, @Param('month') m: string) {
    return this.settlement.approve(tenantUniversityId(), month(m), u.id);
  }

  @Roles('office')
  @Get('settlements/:month/export.pdf')
  async pdf(@Param('month') m: string, @Res() res: Response) {
    const buf = await this.settlement.exportFile(tenantUniversityId(), month(m), 'pdf');
    res.setHeader('content-type', 'application/pdf');
    res.setHeader('content-disposition', `attachment; filename="settlement-${month(m)}.pdf"`);
    res.end(buf);
  }

  @Roles('office')
  @Get('settlements/:month/export.xlsx')
  async xlsx(@Param('month') m: string, @Res() res: Response) {
    const buf = await this.settlement.exportFile(tenantUniversityId(), month(m), 'xlsx');
    res.setHeader('content-type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('content-disposition', `attachment; filename="settlement-${month(m)}.xlsx"`);
    res.end(buf);
  }

  /** NF-15: the office decides whether a flagged run counts. */
  @Roles('office')
  @Patch('runs/:id/verdict')
  @AuditedByHandler()
  verdict(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: VerdictDto) {
    return this.settlement.verdict(tenantUniversityId(), id, dto.verdict ?? null, dto.note, u.id);
  }

  /** DR-08: the driver's month so far and past settlements. */
  @Roles('driver')
  @Get('drivers/me/earnings')
  earnings(@CurrentUser() u: AuthUser, @Query('month') m?: string) {
    return this.settlement.driverEarnings(u.id, u.universityId!, month(m));
  }

  /** SA-04: platform overview across universities. */
  @Roles('super_admin')
  @Get('admin/overview')
  overview(@Query('month') m?: string) {
    return this.settlement.overview(month(m));
  }

  /** SA-05: audit log. Office users see their university only. */
  @Roles('office', 'super_admin')
  @Get('audit')
  auditLog(
    @CurrentUser() u: AuthUser,
    @Query('actorId') actorId?: string,
    @Query('entity') entity?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('universityId') universityId?: string,
    @Query('cursor') cursor?: string,
  ) {
    const date = (s?: string) => (s && /^\d{4}-\d{2}-\d{2}$/.test(s) ? s : undefined);
    const uuid = (s?: string) => (s && /^[0-9a-f-]{36}$/i.test(s) ? s : undefined);
    return this.audit.list({
      universityId: u.role === 'office' ? u.universityId : uuid(universityId),
      actorId: uuid(actorId),
      entity: entity?.slice(0, 60) || undefined,
      from: date(from),
      to: date(to),
      cursor: uuid(cursor),
    });
  }

  @Roles('office', 'super_admin')
  @Get('audit/entities')
  auditEntities(@CurrentUser() u: AuthUser) {
    return this.audit.entities(u.role === 'office' ? u.universityId : undefined);
  }
}
