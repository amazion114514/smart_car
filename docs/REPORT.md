# 代码质量、风险分析与改进建议（smart_car）

一、第三方依赖与构建/运行依赖
- MCU/工具链：Keil MDK C251（工程：软件/Project/MDK/SEEKFREE.uvproj）
- 厂商库：逐飞 Seekfree（软件/Libraries/*）
- 运行时：无外部包管理；通过 Keil 在目标板下载运行

二、静态分析与扫描
- 语言检测：C（嵌入式，C251 方言），少量 ASM（MDU32.ASM）
- 秘密扫描：未发现常见 token/私钥/密码字样（基于正则快速扫描）
- 质量观察：
  - 函数/文件过长：Seror.c ~1200 行，Debug.c ~1100 行
  - 全局变量大量裸露，跨模块读写（并发风险）
  - 编码问题：Motor.c 尾部存在乱码/不可见字符，建议统一 UTF-8
  - 魔数较多：阈值/比例系数散落于代码
  - 中断与主循环数据共享未加 volatile/屏蔽中断保护

三、复杂度热点（需重点治理）
- Seror.c：position_new / Circular_* / Three_branch_road / In_ku / Out_storage 等状态繁杂、分支密集
- Debug.c：菜单/按键处理逻辑冗长，建议抽象 UI 组件
- Read_ADC.c：多层循环+冒泡排序，可优化

四、循环依赖/模块耦合
- myfile.h 聚合所有业务头文件，形成“大一统”包含，提升了隐性耦合
- 业务模块直接操作 HAL 宏与全局数据，边界不清晰

五、并发/内存/边界问题
- ISR 与主循环共享的计时器与标志位（如 gyroscope_time、ramp_time 等）未声明 volatile，存在竞争风险
- 多处数组/索引由常量保护，逻辑安全性依赖阈值判断，建议增加断言/上限检查
- 浮点在 8051 上成本较高，需关注实时性

六、测试现状
- 未发现单元测试/仿真测试代码
- 建议：
  - 将算法（ADC 处理/模糊 PD/卡尔曼/状态机）抽到独立 C 模块，提供 PC 侧可编译宏，配合 Python/CSV 离线回放验证
  - 引入简单的日志/数据采样（UART 输出）以便赛后分析

七、工具与复现
- 提供脚本 scripts/analyze.sh（尝试运行 cppcheck/clang-tidy/semgrep，如未安装则提示安装命令），并给出 cloc 统计
- 建议在本地安装：
  - cppcheck, clang-tidy, clang-format, ripgrep, semgrep, cloc

八、可执行改进建议（>=10 条，按优先级）

Quick Wins（1-2 天）
1. 统一源码编码为 UTF-8，无 BOM；清理乱码（如 MDK/Motor.c 尾部）
2. 为共享状态（ISR<->主循环）添加 volatile 并按需在读/写处禁中断或双缓冲
3. 引入 .clang-format 与 .clang-tidy，先只做格式化与基础规则检查（不改业务逻辑）
4. Read_ADC：冒泡排序改插入排序或选择中位数（常数更优），归一化参数提取为常量表
5. myfile.h 改为“最小可见”按需包含，或在 MDK/USER 工程中为每个模块配置独立包含列表

短期（1-2 周）
6. 拆分 Seror.c：按“感知（识别）/状态机/控制输出/UI 显示”四个子模块重构，公共状态放入 data.h（只读视图）
7. 建立 DataHub（采集态）：封装 GUI_AD/Pitch/Yaw/里程等对外只读接口，减少全局可写
8. 明确物理单位/坐标系与范围（速度/角度/里程），统一饱和策略，去除魔数（使用 const 配置）
9. 引入离线算法单元测试（PC 侧编译宏），对 Fuzzy/Kalman/Position 判定做数据回放
10. 增加日志与参数导出（UART/蓝牙），便于场地调参与复盘

中期（3-6 周）
11. 将互补滤波与卡尔曼滤波合并为统一姿态估计模块，支持运行时切换与参数热更新
12. 速度控制拆分为“期望生成（场景->速度）”与“底层闭环（PID）”，为未来 MPC/前瞻控制预留接口
13. 以表驱动/配置文件化管理赛道元素阈值，支持 EEPROM/Flash 存储与加载
14. 构建最小仿真环境（定点化/固定周期），用脚本自动回放传感器数据集，评估实时性与稳定性
15. 逐步将浮点热路径替换为定点实现（特别是 Read_ADC 归一化、误差与 PD 计算）

九、后续任务清单（落地）
- Quick Wins：1-5
- 短期：6-10
- 中期：11-15

十、图表
- 架构与依赖：docs/diagrams/architecture.mmd, module-deps.mmd
- 调度与调用：docs/diagrams/callgraph_main_isr.mmd
