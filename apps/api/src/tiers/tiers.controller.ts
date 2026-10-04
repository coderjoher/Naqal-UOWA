import { Body, Controller, Get, Put } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators';
import { ReplaceTiersDto } from './tiers.dto';
import { TiersService, tenantUniversityId } from './tiers.service';

@ApiTags('tiers')
@ApiBearerAuth()
@Controller('tiers')
export class TiersController {
  constructor(private readonly tiers: TiersService) {}

  @Roles('office', 'student', 'driver')
  @Get()
  list() {
    return this.tiers.list(tenantUniversityId());
  }

  @Roles('office')
  @Put()
  replace(@Body() dto: ReplaceTiersDto) {
    return this.tiers.replace(tenantUniversityId(), dto.tiers);
  }
}
