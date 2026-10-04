import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { stripPhone } from '../drivers/phone';
import { ArrayMaxSize, ArrayMinSize, IsIn, IsOptional, IsString, IsUUID, Matches, MaxLength, ValidateNested } from 'class-validator';

export class RosterRowDto {
  @ApiProperty() @IsString() @Matches(/^[A-Za-z0-9-]{1,40}$/) studentId: string;
  @ApiProperty() @IsString() @MaxLength(160) name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(160) nameAr?: string;
  @ApiProperty({ enum: ['male', 'female'] }) @IsIn(['male', 'female']) gender: 'male' | 'female';
}

export class ImportRosterDto {
  @ApiProperty({ type: [RosterRowDto] })
  @ValidateNested({ each: true })
  @Type(() => RosterRowDto)
  @ArrayMinSize(1)
  @ArrayMaxSize(20000)
  rows: RosterRowDto[];
}

/** Gender and name are not editable: they come from the university record (ST-02). */
export class UpdateStudentProfileDto {
  @ApiPropertyOptional({ example: '07701234567' }) @IsOptional() @Transform(stripPhone) @Matches(/^(\+?964|0)?7\d{9}$/) phone?: string;
  @ApiPropertyOptional() @IsOptional() @IsUUID() defaultPointId?: string;
}
