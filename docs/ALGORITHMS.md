# 关键功能与算法说明

本节列出核心算法的位置、思路、复杂度与优化建议。

1) ADC 多次采样 + 排序中值平滑 + 归一化
- 位置：MDK/Read_ADC.c::Read_ADC()
- 思路：
  - 每通道采样 10 次，使用冒泡排序后取中间 4 个求均值，得到 AD_valu[i]
  - 对每通道做 6 点滑动平均（ADD_valu 环形窗口），得到 ADDD_valu[i]
  - 线性归一化到 GUI_AD[i]，限定最小值 Min_AD[i] 与上界 Range
- 复杂度：
  - 时间：O(C × N^2)（C=13 通道，N=10 次/通道，常数小）
  - 空间：O(C × N)
- 建议：
  - 将冒泡排序替换为“选择 4 个中值”的快速选择（O(N)) 或插入排序（N=10 时更优常数）
  - 将 Range/Min_AD 作为校准参数持久化，支持赛前一键校准

2) 舵机/底盘循迹控制（分区 + 模糊 PD）
- 位置：MDK/Seror.c::position_new(), Fuzzy_P(), Fuzzy_D(), ZW_judge()
- 思路：
  - 基于横向/斜向误差（error_heng/error_xie）判定直道/弯道（ZW_judge）
  - 直道：以 (sqrt(ZLAD)-sqrt(ZRAD))/(总和) 构造误差，PD 输出
  - 弯道：基于误差与误差变化率的模糊规则表（7×7），加权解模糊得到 Kp/Kd 或直接 U
  - 圆环/三岔/坡道：在 space_flag 的框架下切换不同误差构造与参数
- 复杂度：
  - position_new：O(1)
  - Fuzzy_P/D：常数时间，最多 4 条规则有效，O(1)
- 建议：
  - 将不同工况的误差构造与参数集抽象为 Strategy，避免大量条件分支
  - 关键参数通过表驱动与配置（EEPROM/常量表）管理，便于赛道迁移

3) 电机速度闭环（双环 PID）
- 位置：MDK/Motor.c::encode(), motor_pid(), motor_control()
- 思路：
  - encode：从定时器计数器读取脉冲，结合方向位换算正负速度，清计数并积分路程
  - motor_pid：根据不同工况生成左右轮 exp_speed_{l,r}，对 L/R 速度分别做 PID + 饱和
  - motor_control：根据占空比正负控制正反转两路 PWM
- 复杂度：
  - O(1) per tick
- 建议：
  - 明确单位（m/s, 脉冲/周期）并统一比例常数，避免魔数
  - 分离“期望速度生成”和“速度闭环”，并给出开关量限幅与死区处理

4) 姿态估计（互补滤波 + 卡尔曼滤波）
- 位置：MDK/Gyroscope.c 与 MDK/Kalman_cal.c
- 思路：
  - Gyroscope：加速度三轴反三角换算 Pitch（Angle_pitch），与陀螺仪角速度互补融合得到 pit；Yaw 由 Z 角速度积分
  - Kalman_cal：2×2 状态（angle, gyro_bias），标准离散卡尔曼迭代（Q/R 可调），Pitch/Roll 估计
- 复杂度：O(1)
- 建议：
  - Yaw 角采用互补或一阶漂移补偿，避免纯积分漂移
  - 对采样周期 dt 浮动做保护（基于计时器实测）

5) 圆环/三岔/坡道场景识别
- 位置：MDK/Seror.c::Circular_zuo/Circular_syou/Three_branch_road/podao
- 思路：阈值 + 组合关系 + Yaw 差辅助，进入/退出条件基于传感器范围与计时器
- 复杂度：O(1)
- 建议：
  - 使用有名常量与结构化配置体替代散落的阈值魔数
  - 将识别状态机拆分到独立模块，输出统一的 Scene 状态

补充：
- Out_storage/In_ku（出入库）
  - 位置：MDK/Seror.c
  - 思路：通过 road_sum 里程阈值与固定打角 + Yaw 角差关闭，时序化进入/退出
  - 建议：引入安全状态与异常兜底；Yaw 与路程双条件确认
