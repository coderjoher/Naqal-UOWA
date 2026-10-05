import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDateString, IsIn, IsInt, IsOptional, IsString, IsUUID, Length, Max, MaxLength, Min, ValidateIf } from 'class-validator';
import type { Response } from 'express';
import { AnnouncementsService } from '../announcements/announcements.service';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { reportCsv } from '../reports/metrics';
import { ReportsService } from '../reports/reports.service';
import { monthRange } from '../settlement/settlement.service';
import { monthOf } from '../subscriptions/period-policy';
import { tenantUniversityId } from '../tiers/tiers.service';
import { FeedbackService } from './feedback.service';

export class RatingDto {
  @ApiProperty({ minimum: 1, maximum: 5 }) @Type(() => Number) @IsInt() @Min(1) @Max(5) stars!: number;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500) comment?: string;
}

export const PROBLEM_CATEGORIES = ['late', 'driver', 'vehicle', 'safety', 'app', 'other'] as const;

export class ProblemDto {
  @ApiProperty({ enum: PROBLEM_CATEGORIES }) @IsIn(PROBLEM_CATEGORIES) category!: (typeof PROBLEM_CATEGORIES)[number];
  @ApiProperty() @IsString() @Length(5, 1000) text!: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() requestId?: string;
}

export class ReplyDto {
  @ApiProperty() @IsString() @Length(2, 1000) reply!: string;
}

export class AnnouncementDto {
  @ApiProperty() @IsString() @Length(2, 120) title!: string;
  @ApiProperty() @IsString() @Length(2, 1000) body!: string;
  @ApiProperty({ enum: ['all', 'wave', 'point'] }) @IsIn(['all', 'wave', 'point']) target!: 'all' | 'wave' | 'point';
  @ApiPropertyOptional() @ValidateIf((o) => o.target === 'wave') @IsUUID() waveId?: string;
  @ApiPropertyOptional({ example: '2026-10-06' }) @ValidateIf((o) => o.target === 'wave') @IsDateString() date?: string;
  @ApiPropertyOptional() @ValidateIf((o) => o.target === 'point') @IsUUID() pointId?: string;
  @ApiPropertyOptional({ minimum: 1, maximum: 30 }) @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(30) days?: number;
}

const page = (cursor?: string) => (cursor && /^[0-9a-f-]{36}$/i.test(cursor) ? cursor : undefined);

@ApiTags('feedback')
@ApiBearerAuth()
@Controller()
export class FeedbackController {
  constructor(
    private readonly feedback: FeedbackService,
    private readonly announcements: AnnouncementsService,
    private readonly reports: ReportsService,
  ) {}

  // ── student ──────────────────────────────────────────────────────────────────

  /** ST-10 */
  @Roles('student')
  @Get('rides/history')
  rideHistory(@CurrentUser() u: AuthUser, @Query('cursor') cursor?: string) {
    return this.feedback.rideHistory(u.id, page(cursor));
  }

  /** ST-10 */
  @Roles('student')
  @Get('payments/me')
  payments(@CurrentUser() u: AuthUser, @Query('cursor') cursor?: string) {
    return this.feedback.paymentHistory(u.id, page(cursor));
  }

  /** ST-11 */
  @Roles('student')
  @Post('rides/:id/rating')
  rate(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: RatingDto) {
    return this.feedback.rate(u.id, u.universityId!, id, dto.stars, dto.comment);
  }

  /** ST-11 */
  @Roles('student')
  @Post('problems')
  report(@CurrentUser() u: AuthUser, @Body() dto: ProblemDto) {
    return this.feedback.report(u.id, u.universityId!, dto);
  }

  @Roles('student')
  @Get('problems/me')
  myProblems(@CurrentUser() u: AuthUser) {
    return this.feedback.myProblems(u.id);
  }

  /** TO-11: banner. */
  @Roles('student')
  @Get('announcements/active')
  activeAnnouncements(@CurrentUser() u: AuthUser) {
    return this.announcements.active(u.id, u.universityId!);
  }

  // ── office ───────────────────────────────────────────────────────────────────

  @Roles('office')
  @Get('inbox/problems')
  inbox(@Query('status') status?: string) {
    return this.feedback.inbox(status === 'open' || status === 'resolved' ? status : undefined);
  }

  @Roles('office')
  @Patch('problems/:id')
  resolve(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReplyDto) {
    return this.feedback.resolve(id, tenantUniversityId(), u.id, dto.reply);
  }

  @Roles('office')
  @Get('inbox/ratings')
  ratings() {
    return this.feedback.ratings();
  }

  /** TO-11 */
  @Roles('office')
  @Post('announcements')
  announce(@CurrentUser() u: AuthUser, @Body() dto: AnnouncementDto) {
    return this.announcements.create(tenantUniversityId(), u.id, dto);
  }

  @Roles('office')
  @Post('announcements/preview')
  @HttpCode(200)
  async preview(@Body() dto: AnnouncementDto) {
    return { recipients: (await this.announcements.recipients(dto)).length };
  }

  @Roles('office')
  @Get('announcements')
  announcementsList() {
    return this.announcements.list();
  }

  /** TO-10 */
  @Roles('office')
  @Get('reports')
  report_(@Query('month') month?: string, @Query('tierId') tierId?: string) {
    const m = month ?? monthOf(new Date());
    monthRange(m);
    return this.reports.report(m, tierId && /^[0-9a-f-]{36}$/i.test(tierId) ? tierId : undefined);
  }

  @Roles('office')
  @Get('reports/export.csv')
  async csv(@Res() res: Response, @Query('month') month?: string, @Query('tierId') tierId?: string) {
    const m = month ?? monthOf(new Date());
    monthRange(m);
    const r = await this.reports.report(m, tierId && /^[0-9a-f-]{36}$/i.test(tierId) ? tierId : undefined);
    res.setHeader('content-type', 'text/csv; charset=utf-8');
    res.setHeader('content-disposition', `attachment; filename="report-${m}.csv"`);
    res.end(reportCsv(m, r));
  }
}
