#ifndef UTILS_H_
#define UTILS_H_

#include <string>
#include <vector>

namespace utils {

std::wstring Utf8ToWide(const std::string &utf8);
std::string WideToUtf8(const std::wstring &wide);

}  // namespace utils

#endif  // UTILS_H_
