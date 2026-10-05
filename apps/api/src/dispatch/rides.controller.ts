import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Put, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { ArrayMaxSize, IsArray, IsIn, IsOptional, IsUUID, Matches } from 'class-validator';
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

export class MoveDto {
  @ApiProperty() @IsUUID() requestId!: string;
  @ApiProperty({ description: 'The bus (run) to move the student to' }) @IsUUID() runId!: string;
}

export class ExtraRunDto {
  @ApiProperty() @IsUUID() waveId!: string;
  @ApiProperty({ example: '2026-10-05' }) @Matches(DATE) date!: string;
  @ApiProperty() @IsUUID() driverId!: string;
  @ApiProperty({ enum: ['male', 'female'] }) @IsIn(['male', 'female']) gender!: 'male' | 'female';
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

  /** TO-08: move a student to another bus of the same wave (constraints are checked again). */
  @Roles('office')
  @Post('dispatch/move')
  @HttpCode(200)
  async move(@Body() dto: MoveDto) {
    const ref = await this.rides.refOf(dto.requestId);
    return this.engine.move(ref, dto.requestId, dto.runId);
  }

  /** TO-08: add a bus to a dispatched wave; it takes the waitlist. */
  @Roles('office')
  @Post('dispatch/extra-run')
  @HttpCode(200)
  extraRun(@Body() dto: ExtraRunDto) {
    return this.engine.extraRun({ universityId: tenantUniversityId(), waveId: dto.waveId, date: dto.date }, dto.driverId, dto.gender);
  }

  /** Approved drivers who have no run in this wave yet (for an extra bus). */
  @Roles('office')
  @Get('dispatch/free-drivers')
  freeDrivers(@Query('waveId') waveId: string, @Query('date') date: string) {
    return this.rides.freeDrivers(waveId, date);
  }
}
