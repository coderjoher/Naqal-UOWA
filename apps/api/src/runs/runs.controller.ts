import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiProperty, ApiPropertyOptional, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, IsIn, IsISO8601, IsInt, IsLatitude, IsLongitude, IsNumber, IsOptional, IsString, IsUUID, Length, Matches, Min, ValidateNested } from 'class-validator';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { baghdadDate } from '../dispatch/clock';
import { LiveService } from '../live/live.service';
import { NotificationsService } from '../notifications/notifications.service';
import { tenantUniversityId } from '../tiers/tiers.service';
import { ForbiddenException } from '@nestjs/common';
import { RunsService } from './runs.service';

export class RunActionDto {
  @ApiProperty() @IsString() @Length(8, 64) clientId!: string;
  @ApiProperty({ enum: ['start', 'arrive', 'board', 'depart', 'end'] }) @IsIn(['start', 'arrive', 'board', 'depart', 'end']) type!: 'start' | 'arrive' | 'board' | 'depart' | 'end';
  @ApiPropertyOptional() @IsOptional() @IsISO8601() at?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) seq?: number;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() @IsArray() @ArrayMaxSize(80) @IsUUID('all', { each: true }) requestIds?: string[];
}

export class RunActionsDto {
  @ApiProperty({ type: [RunActionDto] }) @IsArray() @ArrayMinSize(1) @ArrayMaxSize(200) @ValidateNested({ each: true }) @Type(() => RunActionDto) actions!: RunActionDto[];
}

export class GpsPointDto {
  @ApiProperty() @IsLatitude() lat!: number;
  @ApiProperty() @IsLongitude() lng!: number;
  @ApiProperty() @IsISO8601() at!: string;
  @ApiPropertyOptional() @IsOptional() @IsNumber() speed?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() heading?: number;
}

export class GpsBatchDto {
  @ApiProperty({ type: [GpsPointDto] }) @IsArray() @ArrayMinSize(1) @ArrayMaxSize(2000) @ValidateNested({ each: true }) @Type(() => GpsPointDto) points!: GpsPointDto[];
}

export class FareDto {
  @ApiProperty() @IsUUID() requestId!: string;
  @ApiProperty() @IsString() @Length(8, 64) clientId!: string;
}

export class ReadDto {
  @ApiPropertyOptional({ type: [String], description: 'Omit to mark all as read' }) @IsOptional() @IsArray() @IsUUID('all', { each: true }) ids?: string[];
}

export class DeviceDto {
  @ApiProperty() @IsString() @Length(20, 4096) token!: string;
  @ApiProperty({ enum: ['android', 'ios', 'web'] }) @IsIn(['android', 'ios', 'web']) platform!: string;
}

@ApiTags('runs')
@ApiBearerAuth()
@Controller()
export class RunsController {
  constructor(
    private readonly runs: RunsService,
    private readonly live: LiveService,
    private readonly notifications: NotificationsService,
  ) {}

  /** DR-04: start / arrive / board / depart / end. Batches replay offline actions in order. */
  @Roles('driver')
  @Post('runs/:id/actions')
  @HttpCode(200)
  act(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: RunActionsDto) {
    return this.runs.act(u.id, u.universityId!, id, dto.actions);
  }

  /** DR-05 / NF-09: GPS points (one live point, or a buffered batch after reconnecting). */
  @Roles('driver')
  @Post('runs/:id/gps')
  @HttpCode(200)
  gps(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: GpsBatchDto) {
    return this.live.ingest(u.id, u.universityId!, id, dto.points);
  }

  /** DR-07: cash fare from a pay-per-ride rider. */
  @Roles('driver')
  @Post('runs/:id/fares')
  @HttpCode(200)
  fare(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: FareDto) {
    return this.runs.fare(u.id, u.universityId!, id, dto);
  }

  @Roles('driver', 'office')
  @Get('runs/:id')
  async run(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    const view = await this.runs.view(id);
    if (u.role === 'driver' && view.driverId !== u.id) throw new ForbiddenException('Not your run');
    return view;
  }

  /** ST-06: the student's own bus and stop. */
  @Roles('student')
  @Get('rides/:id/track')
  track(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.runs.track(u.id, u.universityId!, id);
  }

  /** TO-07: live operations snapshot (sockets push changes afterwards). */
  @Roles('office')
  @Get('live/runs')
  ops(@Query('date') date?: string) {
    return this.runs.ops(tenantUniversityId(), date && /^\d{4}-\d{2}-\d{2}$/.test(date) ? date : baghdadDate(new Date()));
  }

  @Get('notifications/me')
  mine(@CurrentUser() u: AuthUser) {
    return this.notifications.list(u.id);
  }

  @Post('notifications/read')
  @HttpCode(200)
  read(@CurrentUser() u: AuthUser, @Body() dto: ReadDto) {
    return this.notifications.markRead(u.id, dto.ids ?? 'all');
  }

  @Roles('student', 'driver')
  @Post('devices')
  @HttpCode(200)
  device(@CurrentUser() u: AuthUser, @Body() dto: DeviceDto) {
    return this.notifications.registerDevice(u.id, u.universityId!, dto.token, dto.platform);
  }
}
