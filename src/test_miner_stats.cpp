#include "miner_stats.h"
#include <chrono>
#include <filesystem>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <atomic>
using nlohmann::json;
static void require(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
static json readSnapshot(const std::string& path) {
#ifdef _WIN32
    // Windows readers must allow rename/delete while holding an old snapshot.
    HANDLE h = CreateFileA(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    require(h != INVALID_HANDLE_VALUE, "cannot open snapshot");
    std::string data; char block[4096]; DWORD count = 0;
    bool ok = true;
    for (;;) {
        if (!ReadFile(h, block, sizeof(block), &count, nullptr)) { ok = false; break; }
        if (!count) break;
        data.append(block, count);
    }
    CloseHandle(h);
    require(ok, "cannot read snapshot");
    return json::parse(data);
#else
    json data; std::ifstream(path) >> data; return data;
#endif
}
int main(int argc, char** argv) {
    if (argc != 2) return 2;
    const std::filesystem::path root = argv[1];
    std::filesystem::create_directories(root);
    const std::string path = (root / "miner-stats.json").string();
    try {
        json devices = json::array();
        for (int i = 0; i < 8; ++i) devices.push_back({{"index", 7-i}, {"inf_s", 28.4+i}, {"bus_number", 10+i}, {"fan", nullptr}});
        json value = {{"devices", devices}, {"pid", meow::MinerStatsFile::pid()}, {"uptime", 1234}, {"version", "fixture"}};
        {
            meow::MinerStatsFile file(path);
            require(file.write(value), "first snapshot failed");
            json loaded = readSnapshot(path);
            require(loaded == value, "snapshot lost GPU data or precision");
            // A reader must see one complete snapshot while the writer replaces it.
            std::atomic<bool> stop{false}, bad{false};
            std::thread reader([&] {
                while (!stop) {
                    try { json v = readSnapshot(path); if (v["devices"].size() != 8) bad = true; }
                    catch (...) { bad = true; }
                }
            });
            bool writes = true;
            for (int i = 0; i < 100; ++i) { value["uptime"] = i; writes = file.write(value) && writes; }
            stop = true; reader.join();
            require(writes, "snapshot replacement failed");
            require(!bad, "concurrent reader observed a partial or missing snapshot");
            loaded = readSnapshot(path);
            require(loaded["uptime"] == 99, "existing snapshot was not replaced");
#ifdef _WIN32
            HANDLE locked = CreateFileA(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                                       nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
            require(locked != INVALID_HANDLE_VALUE, "cannot lock snapshot for negative test");
            value["uptime"] = 100;
            bool blocked = !file.write(value);
            CloseHandle(locked);
            require(blocked && readSnapshot(path)["uptime"] == 99, "locked snapshot must remain intact");
            require(file.write(value) && readSnapshot(path)["uptime"] == 100, "write must recover after reader closes");
#endif
        }
        require(!std::filesystem::exists(path), "clean shutdown left a stale snapshot");
        {
            meow::MinerStatsFile disabled("");
            require(!disabled.enabled() && disabled.write(value), "disabled monitoring should be a no-op");
            meow::MinerStatsFile invalid((root / "missing" / "stats.json").string());
            require(!invalid.write(value), "invalid destination did not report failure");
        }
        require(std::filesystem::is_empty(root), "temporary snapshot leaked");
        std::filesystem::remove(root);
        std::cout << "atomic stats: eight devices, null telemetry, replacement, concurrent reads, cleanup and errors PASS\n";
        return 0;
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
