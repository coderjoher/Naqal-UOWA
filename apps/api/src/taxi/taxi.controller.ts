import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsLatitude, IsLongitude, IsOptional, IsString, Length, Max, MaxLength, Min } from 'class-validator';
import type { TaxiDirection } from '@prisma/client';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { tenantUniversityId } from '../tiers/tiers.service';
import { TaxiService } from './taxi.service';

const DIRECTIONS = ['to_campus', 'from_campus'] as const;

export class TaxiPointDto {
  @ApiProperty() @Type(() => Number) @IsLatitude() lat!: number;
  @ApiProperty() @Type(() => Number) @IsLongitude() lng!: number;
}

export class TaxiQuoteDto extends TaxiPointDto {
  @ApiProperty({ enum: DIRECTIONS }) @IsIn(DIRECTIONS) direction!: TaxiDirection;
}

export class TaxiRequestDto extends TaxiQuoteDto {
  @ApiPropertyOptional({ description: 'Where exactly, e.g. "near the mosque gate"' }) @IsOptional() @IsString() @MaxLength(120) label?: string;
  @ApiProperty({ description: 'Client-generated key; a retry returns the same ride' }) @IsString() @Length(8, 64) clientId!: string;
}

export class TaxiSettingsDto {
  @ApiPropertyOptional() @IsOptional() @IsBoolean() taxiEnabled?: boolean;
  @ApiPropertyOptional({ description: 'IQD' }) @IsOptional() @IsInt() @Min(0) @Max(100_000) taxiBaseFare?: number;
  @ApiPropertyOptional({ description: 'IQD per km' }) @IsOptional() @IsInt() @Min(0) @Max(20_000) taxiPerKm?: number;
  @ApiPropertyOptional({ description: 'IQD' }) @IsOptional() @IsInt() @Min(0) @Max(200_000) taxiMinFare?: number;
  @ApiPropertyOptional({ description: 'How long drivers can accept a request' }) @IsOptional() @IsInt() @Min(30) @Max(900) taxiOfferSeconds?: number;
}

/** P10 campus taxis (TX-01..TX-06). */
@ApiTags('taxi')
@ApiBearerAuth()
@Controller('taxi')
export class TaxiController {
  constructor(private readonly taxi: TaxiService) {}

  // ── student ──────────────────────────────────────────────────────────────────

  @Roles('student')
  @Get('quote')
  quote(@CurrentUser() u: AuthUser, @Query() q: TaxiQuoteDto) {
    return this.taxi.quote(u.universityId!, q.direction, q);
  }

  @Roles('student')
  @Post('rides')
  request(@CurrentUser() u: AuthUser, @Body() dto: TaxiRequestDto) {
    return this.taxi.request(u.universityId!, u.id, dto);
  }

  @Roles('student')
  @Get('rides/me')
  mine(@CurrentUser() u: AuthUser) {
    return this.taxi.mine(u.id);
  }

  @Roles('student')
  @Get('rides/:id')
  ride(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.taxi.forStudent(u.id, id);
  }

  @Roles('student', 'driver')
  @Post('rides/:id/cancel')
  @HttpCode(200)
  cancel(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return u.role === 'driver' ? this.taxi.cancelByDriver(u.universityId!, u.id, id) : this.taxi.cancelByStudent(u.universityId!, u.id, id);
  }

  // ── driver ───────────────────────────────────────────────────────────────────

  @Roles('driver')
  @Post('driver/online')
  @HttpCode(200)
  online(@CurrentUser() u: AuthUser, @Body() dto: TaxiPointDto) {
    return this.taxi.heartbeat(u.universityId!, u.id, dto);
  }

  @Roles('driver')
  @Post('driver/offline')
  @HttpCode(200)
  offline(@CurrentUser() u: AuthUser) {
    return this.taxi.goOffline(u.universityId!, u.id);
  }

  @Roles('driver')
  @Get('driver/offers')
  offers(@CurrentUser() u: AuthUser) {
    return this.taxi.offersFor(u.universityId!, u.id);
  }

  @Roles('driver')
  @Get('driver/rides')
  driverRides(@CurrentUser() u: AuthUser) {
    return this.taxi.driverHistory(u.id);
  }

  @Roles('driver')
  @Get('driver/rides/:id')
  driverRide(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.taxi.forDriver(u.id, id);
  }

  @Roles('driver')
  @Post('rides/:id/accept')
  @HttpCode(200)
  accept(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.taxi.accept(u.universityId!, u.id, id);
  }

  @Roles('driver')
  @Post('rides/:id/arrive')
  @HttpCode(200)
  arrive(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.taxi.arrive(u.universityId!, u.id, id);
  }

  @Roles('driver')
  @Post('rides/:id/start')
  @HttpCode(200)
  start(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.taxi.start(u.universityId!, u.id, id);
  }

  @Roles('driver')
  @Post('rides/:id/end')
  @HttpCode(200)
  end(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.taxi.end(u.universityId!, u.id, id);
  }

  // ── office ───────────────────────────────────────────────────────────────────

  @Roles('office', 'super_admin')
  @Get('settings')
  settings() {
    return this.taxi.settings(tenantUniversityId());
  }

  @Roles('office', 'super_admin')
  @Patch('settings')
  updateSettings(@Body() dto: TaxiSettingsDto) {
    return this.taxi.updateSettings(tenantUniversityId(), dto);
  }

  @Roles('office', 'super_admin')
  @Get('overview')
  overview(@Query('date') date?: string) {
    return this.taxi.overview(tenantUniversityId(), date && /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : undefined);
  }
}
