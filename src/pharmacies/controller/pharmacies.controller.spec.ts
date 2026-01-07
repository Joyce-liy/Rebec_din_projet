import { Test, TestingModule } from '@nestjs/testing';
import { PharmaciesController } from './pharmacies.controller';

describe('PharmaciesController', () => {
  let controller: PharmaciesController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PharmaciesController],
    }).compile();

    controller = module.get<PharmaciesController>(PharmaciesController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
