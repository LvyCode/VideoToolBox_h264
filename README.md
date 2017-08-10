# VideoToolBox_h264
H.264  视频捕捉
***VideoToolBox iOS8.0推出   同期block也推出出来了***

`VideoToolBox工作流程
VideoToolBox基于Core Foundation库函数，c语言 
创建session——>设置编码相关参数——>开始编码——>循环输入源数据（yuv类型的数据，直接从摄像头获取）——>获取编码后的H264数据——>结束编码`

**CMSampleBuffer编码格式**
- CMTime 时间戳
- CMVideoFormatDesk 图像存储方式
- CMPixelBuffer编码后   CVPixelBuffer编码前
***

`时间和空间的相似性对数据进行压缩`
**视频编码格式H.264**
##代码流程
- 简单UI
- 配置 AV Foundation捕捉回话
- 配置  VideoToolBox
- 开始捕捉
- AV Foundation捕捉到视频
- 停止捕捉
- 结束AV Foundation
