import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsBoolean, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min, ValidateNested } from 'class-validator';

export class DocumentRequirementDto {
  @ApiProperty({ example: 'driving_licence' }) @Matches(/^[a-z][a-z0-9_]{1,40}$/) key: string;
  @ApiProperty() @IsString() @MaxLength(80) label: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(80) labelAr?: string;
  @ApiProperty() @IsBoolean() required: boolean;
}

export class DriverRequirementsDto {
  @ApiProperty({ type: [DocumentRequirementDto] })
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => DocumentRequirementDto)
  documents: DocumentRequirementDto[];

  @ApiProperty({ example: ['coaster', 'minibus'] }) @IsArray() @ArrayMaxSize(10) @Matches(/^[a-z][a-z0-9_]{1,30}$/, { each: true }) vehicleTypes: string[];
  @ApiProperty() @IsInt() @Min(4) @Max(80) minSeats: number;
  @ApiProperty() @IsInt() @Min(1) @Max(40) maxVehicleAgeYears: number;
}
