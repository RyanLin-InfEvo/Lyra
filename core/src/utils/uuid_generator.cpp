#include <random>
#include <uuid.h>

#include "uuid_generator.h"

std::string UuidGenerator::generate_v4() {
  thread_local std::random_device rd;
  thread_local std::mt19937 gen(rd());

  uuids::uuid_random_generator uuid_gen{gen};
  uuids::uuid const id = uuid_gen();

  return uuids::to_string(id);
}