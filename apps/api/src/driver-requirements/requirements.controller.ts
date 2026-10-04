import { Body, Controller, Get, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators';
import { tenantUniversityId } from '../tiers/tiers.service';
import { DriverRequirementsDto } from './requirements.dto';
import { DriverRequirementsService } from './requirements.service';

@ApiTags('driver-requirements')
@ApiBearerAuth()
@Controller('driver-requirements')
export class DriverRequirementsController {
  constructor(private readonly reqs: DriverRequirementsService) {}

  @Roles('office', 'driver')
  @Get()
  get() {
    return this.reqs.get(tenantUniversityId());
  }

  @Roles('office')
  @Put()
  set(@Body() dto: DriverRequirementsDto) {
    return this.reqs.set(tenantUniversityId(), dto);
  }

  @Roles('office', 'driver')
  @Get('registration-form')
  form() {
    return this.reqs.registrationForm(tenantUniversityId());
  }
}
