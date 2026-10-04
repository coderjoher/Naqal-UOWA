import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators';
import { tenantUniversityId } from '../tiers/tiers.service';
import { CreateWaveDto, UpdateWaveDto } from './waves.dto';
import { WavesService } from './waves.service';

@ApiTags('waves')
@ApiBearerAuth()
@Controller('waves')
export class WavesController {
  constructor(private readonly waves: WavesService) {}

  @Roles('office', 'student', 'driver')
  @Get()
  list() {
    return this.waves.list(tenantUniversityId());
  }

  @Roles('office')
  @Post()
  create(@Body() dto: CreateWaveDto) {
    return this.waves.create(tenantUniversityId(), dto);
  }

  @Roles('office')
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateWaveDto) {
    return this.waves.update(tenantUniversityId(), id, dto);
  }
}
