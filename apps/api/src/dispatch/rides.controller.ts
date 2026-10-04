import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsOptional, IsUUID, Matches } from 'class-validator';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { tenantUniversityId } from '../tiers/tiers.service';
import { baghdadDate } from './clock';
import { DispatchEngine } from './dispatch.engine';
import { RidesService } from './rides.service';

const DATE = /^\d{4}-\d{2}-\d{2}$/;

export class RideRequestDto {
  @ApiProperty() @IsUUID() waveId!: string;
  @ApiPropertyOptional({ example: '2026-10-05', description: 'Today (default) or tomorrow' }) @IsOptional() @Matches(DATE) date?: string;
  @ApiPropertyOptional({ description: 'Defaults to the student’s gathering point' }) @IsOptional() @IsUUID() pointId?: string;
}

export class AvailabilityDto {
  @ApiProperty({ example: '2026-10-05' }) @Matches(DATE) date!: string;
  @ApiProperty({ type: [String] }) @IsArray() @ArrayMaxSize(20) @IsUUID('all', { each: true }) waveIds!: string[];
}

export class PlanDto {
  @ApiProperty() @IsUUID() waveId!: string;
  @ApiProperty({ example: '2026-10-05' }) @Matches(DATE) date!: string;
}

@ApiTags('rides')
@ApiBearerAuth()
@Controller()
export class RidesController {
  constructor(
    private readonly rides: RidesService,
    private readonly engine: DispatchEngine,
  ) {}

  @Roles('student')
  @Get('rides/options')
  options(@CurrentUser() u: AuthUser) {
    return this.rides.options(u.id);
  }

  @Roles('student')
  @Post('rides')
  request(@CurrentUser() u: AuthUser, @Body() dto: RideRequestDto) {
    return this.rides.request(u.id, u.universityId!, dto);
  }

  @Roles('student')
  @Get('rides/me')
  mine(@CurrentUser() u: AuthUser) {
    return this.rides.mine(u.id);
  }

  @Roles('student')
  @Post('rides/:id/cancel')
  @HttpCode(200)
  cancel(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.rides.cancel(u.id, u.universityId!, id);
  }

  @Roles('driver')
  @Get('drivers/me/availability')
  availability(@CurrentUser() u: AuthUser) {
    return this.rides.availability(u.id);
  }

  @Roles('driver')
  @Put('drivers/me/availability')
  setAvailability(@CurrentUser() u: AuthUser, @Body() dto: AvailabilityDto) {
    return this.rides.setAvailability(u.id, u.universityId!, dto.date, dto.waveIds);
  }

  /** DR-03: runs for a date (default today) with ordered stops and passengers. Approved drivers only. */
  @Roles('driver')
  @Get('drivers/me/runs')
  runs(@CurrentUser() u: AuthUser, @Query('date') date?: string) {
    return this.rides.driverRuns(u.id, date);
  }

  @Roles('office')
  @Get('dispatch')
  board(@Query('date') date?: string) {
    return this.rides.board(date ?? baghdadDate(this.engine.now()));
  }

  /** Plan a wave now instead of waiting for its planning time (runs in the worker). */
  @Roles('office')
  @Post('dispatch/plan')
  @HttpCode(202)
  async plan(@Body() dto: PlanDto) {
    await this.engine.enqueuePlan({ universityId: tenantUniversityId(), waveId: dto.waveId, date: dto.date });
    return { queued: true };
  }
}
