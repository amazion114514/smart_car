# 模块与文件清单（职责/接口/数据流）

目录参考：电磁四轮/软件/Project/MDK 与 Libraries/

- Application
  - USER/main.c
    - 职责：系统入口、初始化、主循环调度（出/入库、模式切换、显示）
    - 主要接口：main()
    - 依赖：headfile.h, myfile.h（聚合 MDK 模块）
  - USER/isr.c
    - 职责：各类中断服务，核心 5ms 控制在 TM1_Isr
    - 主要接口：各中断处理函数（UARTx、INTx、TIMx）
    - 调用链：TM1_Isr -> encode -> motor_pid -> motor_control；icm_open -> Angle_Get；huoer -> 状态计时/限幅

- Init/Board
  - MDK/All_init.c/.h
    - 职责：PWM/ADC/IMU/OLED/计数器/定时器初始化
    - API：all_init(); 宏定义外设引脚（PWM_x, S3010_CH, SPEED*_PLUSE 等）
    - 依赖：seekfree 库（adc_init/pwm_init/pit_timer_ms 等）

- Sensing（传感）
  - MDK/Read_ADC.c/.h
    - 职责：13 路 ADC 采集、排序去噪（10 次采样取 4 个中值平均）、归一化到 GUI_AD[]
    - API：Read_ADC(); 宏映射 ZLAD/QLAD/…/HAD
    - 数据：GUI_AD[13]（对外公共感知数据）
  - MDK/Gyroscope.c/.h
    - 职责：IMU 原始数据换算、互补滤波融合、Pitch/Yaw 输出
    - API：Angle_Get(); data_change(); icm_open();
    - 数据：Pitch, Yaw, pittch
  - MDK/Kalman_cal.c/.h
    - 职责：卡尔曼滤波（pitch/roll），Angle_Cal 调用 ICM 采样
    - API：Kalman_Cal_Pitch/Roll(); Angle_Cal();

- Perception/Decision（感知/决策）
  - MDK/Seror.c/.h
    - 职责：
      - 直/弯识别（ZW_judge）
      - 圆环识别（Circular_zuo/Circular_syou）并使用 Yaw 辅助出环
      - 三岔识别与进入/退出判定（Three_branch_road）
      - 坡道识别/计时（podao）
      - 出入库流程（Out_storage/In_ku）
      - 最终打角（S3010_Direation_Control）与 OLED 显示（scene_show/…）
    - API：见 Seror.h 列表（S3010_Direation_Control, ZW_judge, Circular_*, Three_branch_road, podao, Out_storage, In_ku, scene_show…）
    - 数据：大量全局状态（space_flag/Ramp/Island_*/Yaw/road_sum 等）
  - MDK/Element.c/.h
    - 职责：模板参数切换（阈值组/匹配顺序）
    - API：Element_key()

- Control/Actuation（控制/执行）
  - MDK/Motor.c/.h
    - 职责：编码器读数、左右轮速度估计、差速期望计算（不同场景），电机 PID 与饱和、PWM 输出
    - API：encode(); motor_pid(); motor_control(); huoer();
    - 数据：exp_speed_{l,r}, L/R_err 与积分、L/R_duty、base 参数组

- Debug/UI
  - MDK/Debug.c/.h
    - 职责：OLED 菜单/参数调节；运行时指标显示
    - API：menu(); ADC_SHOW(); DUOJI_Ctro(); xunjiflag(); annulus_PD(); zhidao_pd(); sancha_pd(); huan_xishu();

- Mode Hints
  - MDK/Duan.c/.h
    - 职责：坡道模式提示（基于圈数/次序）
    - API：Po_mode_switch();

- HAL/Drivers
  - Libraries/libraries：board/common/printf
  - Libraries/seekfree_libraries：adc/gpio/pwm/tim/uart/iic/spi…
  - Libraries/seekfree_peripheral：OLED/ICM20602/编码器/无线模块等器件驱动

数据流与协作要点
- Read_ADC -> GUI_AD[] -> Seror（ZW_judge/position_new/元素识别）
- Gyroscope(icm_open/Angle_Get) -> Pitch/Yaw -> Seror（出环/三岔判断/入库策略）
- Seror 计算 Error_angle_out -> S3010_Direation_Control -> pwm_duty(PWMB_CH1_P74)
- TM1_Isr 周期性：encode -> motor_pid -> motor_control
- Out_storage/In_ku 控制 base 与打角，参与 exp_speed 与低层控制

公开 API（核心）
- 初始化：all_init()
- 采集：Read_ADC(); icm_open(); Angle_Get();
- 感知/决策：ZW_judge(); Circular_zuo/syou(); Three_branch_road(); podao();
- 控制：S3010_Direation_Control(); encode(); motor_pid(); motor_control();
- 出入库：Out_storage(); In_ku();
- 显示：scene_show(); ADC_SHOW(); xunjiflag();
