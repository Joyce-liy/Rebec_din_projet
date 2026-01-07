import { Controller, Post, Body } from '@nestjs/common';
import { PharmaciesService } from '../service/pharmacies.service';
import { CreatePharmacieDto } from '../DTO/create-pharmacie.dto';

@Controller('pharmacies')
export class PharmaciesController {
  constructor(private readonly pharmaciesService: PharmaciesService) {}

    @Post()
    create(@Body() body: CreatePharmacieDto) {
    return this.pharmaciesService.create(body);
    }
}
