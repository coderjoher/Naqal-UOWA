import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Patch, Post, Put, Query, UploadedFile, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser, Public, Roles } from '../auth/decorators';
import { tenantUniversityId } from '../tiers/tiers.service';
import { DriverStatus, ReviewAction } from './driver-rules';
import { RequestOtpDto, ReviewDto, UpdateApplicationDto, VerifyOtpDto } from './drivers.dto';
import { DriversService, MAX_DOC_BYTES } from './drivers.service';

const STATUSES: DriverStatus[] = ['draft', 'pending', 'approved', 'rejected', 'suspended'];

@ApiTags('drivers')
@Controller()
export class DriversController {
  constructor(private readonly drivers: DriversService) {}

  @Public()
  @Post('auth/driver/otp')
  @HttpCode(200)
  otp(@Body() dto: RequestOtpDto) {
    return this.drivers.requestOtp(dto.phone);
  }

  @Public()
  @Post('auth/driver/verify')
  @HttpCode(200)
  verify(@Body() dto: VerifyOtpDto) {
    return this.drivers.verifyOtp(dto.phone, dto.code, dto.university);
  }

  @ApiBearerAuth()
  @Roles('driver')
  @Get('drivers/me')
  me(@CurrentUser() u: AuthUser) {
    return this.drivers.mine(u.id, u.universityId!);
  }

  @ApiBearerAuth()
  @Roles('driver')
  @Patch('drivers/me')
  update(@CurrentUser() u: AuthUser, @Body() dto: UpdateApplicationDto) {
    return this.drivers.update(u.id, u.universityId!, dto);
  }

  @ApiBearerAuth()
  @ApiConsumes('multipart/form-data')
  @Roles('driver')
  @Put('drivers/me/documents/:key')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_DOC_BYTES } }))
  upload(@CurrentUser() u: AuthUser, @Param('key') key: string, @UploadedFile() file?: Express.Multer.File) {
    return this.drivers.upload(u.id, u.universityId!, key, file);
  }

  @ApiBearerAuth()
  @Roles('driver')
  @Post('drivers/me/submit')
  @HttpCode(200)
  submit(@CurrentUser() u: AuthUser) {
    return this.drivers.submit(u.id, u.universityId!);
  }

  /** Today's runs (filled in P4). Only approved drivers may see or operate runs. */
  @ApiBearerAuth()
  @Roles('driver')
  @Get('drivers/me/runs')
  async runs(@CurrentUser() u: AuthUser) {
    await this.drivers.assertApproved(u.id);
    return [];
  }

  @ApiBearerAuth()
  @Roles('office')
  @Get('drivers')
  list(@Query('status') status?: string) {
    return this.drivers.list(STATUSES.includes(status as DriverStatus) ? (status as DriverStatus) : undefined);
  }

  @ApiBearerAuth()
  @Roles('office')
  @Get('drivers/:id')
  detail(@Param('id', ParseUUIDPipe) id: string) {
    return this.drivers.detail(id, tenantUniversityId());
  }

  // One route per review action (Express 5 routes do not take inline regex).
  @ApiBearerAuth()
  @Roles('office')
  @Post('drivers/:id/approve')
  @HttpCode(200)
  approve(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReviewDto) {
    return this.review(u, id, 'approve', dto);
  }

  @ApiBearerAuth()
  @Roles('office')
  @Post('drivers/:id/reject')
  @HttpCode(200)
  reject(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReviewDto) {
    return this.review(u, id, 'reject', dto);
  }

  @ApiBearerAuth()
  @Roles('office')
  @Post('drivers/:id/suspend')
  @HttpCode(200)
  suspend(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReviewDto) {
    return this.review(u, id, 'suspend', dto);
  }

  @ApiBearerAuth()
  @Roles('office')
  @Post('drivers/:id/reinstate')
  @HttpCode(200)
  reinstate(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: ReviewDto) {
    return this.review(u, id, 'reinstate', dto);
  }

  private review(u: AuthUser, id: string, action: ReviewAction, dto: ReviewDto) {
    return this.drivers.review(id, u.id, action, dto.note);
  }

  @ApiBearerAuth()
  @Roles('office')
  @Post('drivers/:id/documents/:key/link')
  @HttpCode(200)
  link(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Param('key') key: string) {
    return this.drivers.documentLink(id, key, u.id, tenantUniversityId());
  }
}
