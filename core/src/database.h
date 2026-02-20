#pragma once
#include <string>

// initialize database
void init_database(const std::string &db_path);

// insert artist into database
void insert_artist(const std::string &uuid, const std::string &name);