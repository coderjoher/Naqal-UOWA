import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/decorators';
import { tenantUniversityId } from '../tiers/tiers.service';
import { CreatePointDto, UpdatePointDto } from './points.dto';
import { PointsService } from './points.service';

@ApiTags('gathering-points')
@ApiBearerAuth()
@Controller('gathering-points')
export class PointsController {
  constructor(private readonly points: PointsService) {}

  @Roles('office', 'student', 'driver')
  @Get()
  list() {
    return this.points.list(tenantUniversityId());
  }

  @Roles('office')
  @Post()
  create(@Body() dto: CreatePointDto) {
    return this.points.create(tenantUniversityId(), dto);
  }

  @Roles('office')
  @Patch(':id')
  update(@Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdatePointDto) {
    return this.points.update(tenantUniversityId(), id, dto);
  }

  @Roles('office')
  @Delete(':id')
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.points.deactivate(tenantUniversityId(), id);
  }
}
