import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';
import type { Response } from 'express';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { PaymentsService } from '../payments/payments.service';
import { tenantUniversityId } from '../tiers/tiers.service';
import { SubscriptionsService } from './subscriptions.service';

class CreateSubscriptionDto {
  /** Student number (e.g. W-1001) or user id. */
  @ApiProperty() @IsString() @MaxLength(60) studentId: string;
  @ApiPropertyOptional({ example: '2026-10' }) @IsOptional() @Matches(/^\d{4}-(0[1-9]|1[0-2])$/) month?: string;
}

class ReverseDto {
  @ApiProperty() @IsString() @MinLength(3) @MaxLength(300) reason: string;
}

@ApiTags('subscriptions')
@ApiBearerAuth()
@Controller()
export class SubscriptionsController {
  constructor(
    private readonly subs: SubscriptionsService,
    private readonly payments: PaymentsService,
  ) {}

  @Roles('office')
  @Post('subscriptions')
  create(@CurrentUser() u: AuthUser, @Body() dto: CreateSubscriptionDto) {
    return this.subs.create(tenantUniversityId(), u.id, dto);
  }

  @Roles('office')
  @Get('subscriptions/preview')
  preview(@Query('studentId') studentId: string, @Query('month') month?: string) {
    return this.subs.preview(studentId ?? '', month && /^\d{4}-(0[1-9]|1[0-2])$/.test(month) ? month : undefined);
  }

  @Roles('office')
  @Get('subscriptions')
  list(@Query('month') month?: string) {
    return this.subs.list(month && /^\d{4}-\d{2}$/.test(month) ? month : undefined);
  }

  @Roles('student')
  @Get('subscriptions/me')
  mine(@CurrentUser() u: AuthUser) {
    return this.subs.forStudent(u.id);
  }

  @Roles('office')
  @Post('payments/:id/reverse')
  @HttpCode(200)
  reverse(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReverseDto) {
    return this.payments.reverse(tenantUniversityId(), id, u.id, dto.reason);
  }

  @Roles('office')
  @Get('payments/:id/receipt.pdf')
  async receipt(@Param('id', ParseUUIDPipe) id: string, @Res() res: Response) {
    const pdf = await this.subs.receipt(id);
    res.setHeader('content-type', 'application/pdf');
    res.setHeader('content-disposition', `inline; filename="receipt-${id.slice(0, 8)}.pdf"`);
    res.send(pdf);
  }
}
