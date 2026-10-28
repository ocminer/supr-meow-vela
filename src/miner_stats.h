// Optional local monitoring snapshot. No pool credentials or listening socket.
#pragma once
#include "compat.h"
#include <nlohmann/json.hpp>
#include <cstdio>
#include <fstream>
#include <string>

namespace meow {
class MinerStatsFile {
    std::string path_, temporary_;
    bool owned_ = false;
public:
    explicit MinerStatsFile(const std::string& path) : path_(path) {
        if (!path.empty()) temporary_ = path + ".tmp." + std::to_string(pid());
    }
    MinerStatsFile(const MinerStatsFile&) = delete;
    MinerStatsFile& operator=(const MinerStatsFile&) = delete;
    ~MinerStatsFile() {
        if (owned_) std::remove(path_.c_str());
        if (!temporary_.empty()) std::remove(temporary_.c_str());
    }
    static unsigned long pid() {
#ifdef _WIN32
        return GetCurrentProcessId();
#else
        return static_cast<unsigned long>(getpid());
#endif
    }
    bool enabled() const { return !path_.empty(); }
    bool write(const nlohmann::json& snapshot) {
        if (!enabled()) return true;
        std::ofstream file(temporary_, std::ios::binary | std::ios::trunc);
        if (!file) return false;
        file << snapshot.dump() << '\n';
        file.close();
        if (!file) { std::remove(temporary_.c_str()); return false; }
#ifdef _WIN32
        bool ok = MoveFileExA(temporary_.c_str(), path_.c_str(), MOVEFILE_REPLACE_EXISTING) != 0;
#else
        bool ok = std::rename(temporary_.c_str(), path_.c_str()) == 0;
#endif
        if (!ok) { std::remove(temporary_.c_str()); return false; }
        owned_ = true;
        return true;
    }
};
} // namespace meow
