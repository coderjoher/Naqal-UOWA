import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuditedByHandler } from '../audit/audit.interceptor';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { CreateUniversityDto, UpdateUniversityDto } from './universities.dto';
import { UniversitiesService } from './universities.service';

@ApiTags('universities')
@ApiBearerAuth()
@Controller('universities')
export class UniversitiesController {
  constructor(private readonly universities: UniversitiesService) {}

  @Roles('super_admin')
  @Get()
  list() {
    return this.universities.list();
  }

  @Roles('super_admin')
  @Post()
  create(@Body() dto: CreateUniversityDto) {
    return this.universities.create(dto);
  }

  /** The caller's own university (office, student, driver). */
  @Roles('office', 'student', 'driver')
  @Get('current')
  current(@CurrentUser() user: AuthUser) {
    return this.universities.get(user.universityId!);
  }

  @Roles('super_admin')
  @Get(':id')
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.universities.get(id);
  }

  @Roles('super_admin')
  @Patch(':id')
  @AuditedByHandler()
  update(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateUniversityDto) {
    return this.universities.update(id, dto, user.id);
  }
}
