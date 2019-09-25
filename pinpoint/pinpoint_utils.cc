#include <iostream>
#include <chrono>
#include <string>

#include <unistd.h>

long int get_time()
{
	auto timestamp = std::time(nullptr);
	return timestamp;
}

std::string get_stime()
{
	auto timestamp = std::time(nullptr);
	return std::to_string(timestamp);
}


