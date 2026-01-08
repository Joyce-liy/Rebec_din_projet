import { Controller, Post, Body, Get, Query } from '@nestjs/common';
import { PharmaciesService } from '../service/pharmacies.service';
import { CreatePharmacieDto } from '../DTO/create-pharmacie.dto';

@Controller('pharmacies')
export class PharmaciesController {
  constructor(private readonly pharmaciesService: PharmaciesService) {}

  // 🔹 Création d'une pharmacie
  @Post()
  create(@Body() body: CreatePharmacieDto) {
    return this.pharmaciesService.create(body);
  }

  // 🔹 Récupérer toutes les pharmacies
  @Get()
  findAll() {
    return this.pharmaciesService.findAll();
  }

  // 🔹 Recherche des pharmacies à proximité
    @Get('nearby')
    findNearby(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radius') radius?: string,
    ) {
    console.log('PARAMS REÇUS DANS LE CONTROLLER →', {
        lat,
        lng,
        radius,
    });

    return this.pharmaciesService.findNearby(
        Number(lat),
        Number(lng),
        radius ? Number(radius) : 1000,
    );
    }
}