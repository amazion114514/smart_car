# Smart Car 代码库审计 — 架构与模块边界

本报告聚焦 电磁四轮/smart_car 仓库（STC16F40K128 平台，Keil C251 工程），从架构、模块边界、依赖关系出发，给出改进建议与优先级路线图。

- 目标硬件与运行环境：
  - MCU: STC16F40K128（8051 架构）
  - 工具链：Keil MDK C251（工程文件位于 软件/Project/MDK/）
  - 厂商库：逐飞科技 Seekfree 库（软件/Libraries 下）

- 顶层目录（与本架构相关）：
  - 电磁四轮/硬件：硬件设计资料（原理图/PCB zip）
  - 电磁四轮/软件/Libraries：通用板级与外设驱动（seekfree_* 系列）
  - 电磁四轮/软件/Project/MDK：业务模块与功能实现（.c/.h + Keil 工程）
  - 电磁四轮/软件/Project/USER：入口与中断（main.c, isr.c）

一、整体架构（Mermaid 图）

参见 docs/diagrams/architecture.mmd 与 docs/diagrams/module-deps.mmd，可直接在支持 Mermaid 的查看器中打开。

二、模块边界与职责

- 应用层（Application）
  - USER/main.c：系统入口，时钟/sys init、board_init、all_init、主循环任务调度（出入库、模式切换与显示）
  - USER/isr.c：中断服务（UARTx、EXTI、TIMx），核心 5ms 调度在 TM1_Isr 中完成（编码器测速、IMU 更新、电机 PID、执行器输出、计时器更新）

- 业务逻辑层（Control/Perception）
  - MDK/Read_ADC.c：多通道 ADC 采集、滑动窗口与中值化处理、归一化映射（GUI_AD[]）
  - MDK/Seror.c：赛道感知与控制决策（直/弯判定、圆环识别、三岔、坡道、出入库策略、舵机最终打角与显示）
  - MDK/Motor.c：编码器读数、期望车速计算、左右轮 PID、PWM 占空比输出
  - MDK/Gyroscope.c + MDK/Kalman_cal.c：IMU 数据处理与姿态估计（互补滤波/卡尔曼滤波），Pitch/Yaw 计算
  - MDK/Element.c：模板开关与元素阈值切换
  - MDK/All_init.c：外设初始化与系统上电配置
  - MDK/Debug.c：OLED 菜单、调参与运行态显示

- 硬件抽象层（HAL/Drivers）
  - Libraries/libraries：板级初始化、通用外设包装（GPIO/UART/PWM/ADC 等）
  - Libraries/seekfree_peripheral：具体器件驱动（OLED/ICM20602/蓝牙等）
  - Libraries/seekfree_libraries：底层外设适配与通用模块（fifo、定时器、NVIC、SPI/I2C 等）

三、关键依赖路径

- main -> board_init -> all_init -> 外设初始化（PWM/ADC/IMU/OLED/计数器/定时器）
- TM1_Isr（5ms）：encode -> motor_pid -> motor_control；icm_open -> Angle_Get；若干状态计时器
- 业务循环：Read_ADC -> 感知/判定（Seror：ZW_judge/Circular/Three_branch_road/podao）-> 角度误差 Error_angle_out -> S3010_Direation_Control（舵机）
- Seekfree 驱动：adc_once/pwm_init/pwm_duty/ctimer_count_* 等

四、模块依赖图（简化）

见 docs/diagrams/module-deps.mmd，核心关系：
- USER(main/isr) 依赖 业务模块（Seror/Motor/Gyroscope/Read_ADC/...）
- 业务模块依赖 HAL（seekfree_* 与 board/common）
- 硬件依赖底层 MCU 与器件

五、边界与约束

- 时间约束：核心控制周期 5ms（TIM1 中断），算法必须常数时间或小常数复杂度
- 资源约束：8051 架构、RAM/ROM 有限，应避免大数组/浮点重计算
- 并发边界：主循环与中断共享全局变量（需 volatile/临界区保护）

六、发现的问题（结构层面）

- 业务模块耦合度高（Seror.c > 1k 行，含感知/控制/UI 混杂）
- 全局状态过多，跨模块读写，缺少一致的前缀与访问封装
- 中文编码与不可见字符在少量源码中存在（例如 Motor.c 尾部乱码），存在潜在编译/可移植性风险
- 接口边界未对外显式暴露数据契约（单位、坐标、范围、饱和策略）

七、改进方向（概要）

- 分层与解耦：将 Seror 按“感知/状态机/控制输出/UI 显示”拆分为独立子模块
- 明确数据模型：将 ADC/IMU/里程等数据经统一 DataHub 输出，控制模块仅消费
- 并发安全：ISR 与主循环共享变量使用 volatile + 读写时禁中断或双缓冲
- 性能与资源：浮点热路径改为定点；ADC 排序改选择/中位数快速选择
- 质量保障：引入 clang-tidy/cppcheck/clang-format 与最小单元测试（可在 PC 侧对算法做离线仿真）

详细模块清单与 API 见 docs/MODULES.md；算法说明见 docs/ALGORITHMS.md；整体验收与建议见 docs/REPORT.md。
