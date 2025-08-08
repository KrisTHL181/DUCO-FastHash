# DUCO-FastHash
使得DUCO的官方挖掘器的性能插上传统挖矿性能的翅膀！

## 功能简介

本项目是一个高性能的 DUCO-S1 哈希计算核心，基于 Rust 实现，支持：

- ✅ **SIMD 加速**：充分利用 CPU 的向量指令（AVX2 / NEON），大幅提升哈希吞吐
- ✅ **轻量设计**：仅实现核心哈希逻辑，不绑定矿池、不依赖 Python 脚本
- ✅ **跨平台支持**：可在 x86_64 PC 和 aarch64 手机（Termux）上编译运行
- ✅ **极致简洁**：`cargo build --release` 即可获得最优性能，无需复杂编译参数
- 💬 Python部分由官方原版进行部分修改，配置文件兼容

---

## 使用方法

### 1. 安装依赖

确保已安装：
- [Rust](https://rust-lang.org)（推荐使用 `rustup`）
- `cargo` 构建工具

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 2. 编译

```bash
git clone https://github.com/KrisTHL181/DUCO-FastHash.git
cd DUCO-FastHash
cd [CPU]版本或[GPU]版本
cargo build --release
```

### 3. 作为库使用（供 Python 调用）

本项目可编译为 `cdylib`，供 Python 通过 `pyo3` 调用：

```toml
# Cargo.toml
[lib]
crate-type = ["cdylib"]
```

Python 示例：

```python
import libducohasher

hasher = libducohasher.DUCOHasher(b"job_base_string")
nonce = hasher.DUCOS1(expected_hash_bytes, diff=1000000, job_mul=1)
if nonce:
    print(f"找到 nonce: {nonce}")
```

> 🔧 可用于构建高性能矿机、性能测试，或使用GPU版本加速。

### 4. （可选）克隆原始仓库

本项目为避免不安全和纠纷删除了原始仓库的一些文件，如果在运行时出现故障，可以将那些文件重新克隆回来。

---

## 免责声明
- 本项目**附加功能不完全可以用配置文档控制**，如果你需要修改某些参数，请修改代码中对应部分并重新编译或运行。
- 本项目**不鼓励或支持任何违反服务条款的挖矿行为**。
- DUCO 官方存在一个名为 “Kolka 系统” 的中心化机制，本项目在极端加速挖矿的过程中必然遭到会因该系统遇到极高的难度调整，不建议试图绕过。
- **请勿用于破坏系统稳定或获取不当收益。**
- **请勿通过黑客手段在他人设备上进行不当挖矿行为。**

---

## 许可证
本程序使用 `Apache` 许可证授权。
