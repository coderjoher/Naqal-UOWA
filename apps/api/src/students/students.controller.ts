import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { AuthUser, CurrentUser, Roles } from '../auth/decorators';
import { tenantUniversityId } from '../tiers/tiers.service';
import { ImportRosterDto, UpdateStudentProfileDto } from './students.dto';
import { StudentsService } from './students.service';

@ApiTags('students')
@ApiBearerAuth()
@Controller('students')
export class StudentsController {
  constructor(private readonly students: StudentsService) {}

  @Roles('student')
  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.students.profile(user.id);
  }

  @Roles('student')
  @Patch('me')
  update(@CurrentUser() user: AuthUser, @Body() dto: UpdateStudentProfileDto) {
    return this.students.updateProfile(user.id, dto);
  }

  @Roles('office')
  @Get()
  list() {
    return this.students.list();
  }

  @Roles('office')
  @Post('roster')
  importRoster(@Body() dto: ImportRosterDto) {
    return this.students.importRoster(tenantUniversityId(), dto.rows);
  }

  @Roles('office')
  @Post(':studentId/activation-code')
  issueCode(@Param('studentId') studentId: string) {
    return this.students.issueActivationCode(studentId);
  }
}
