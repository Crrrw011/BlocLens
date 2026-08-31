# Gym & Zone Browsing Refine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 复用 Gym Photo Carousel、真实按需加载与缓存、修复 Home SafeArea、精简 GymDetail/ZoneDetail 信息层级并重排筛选器，满足 22 项单元测试与 31 项 UI 测试。

**Architecture:** 新增 GymPhotoLoader 抽象 + Actor 缓存 + ViewModel 控制按需加载与取消；TabView paging 复用单一 GymPhotoCarouselView；Home/GymDetail 共享 loader；FacilityStatus 独立映射；ZoneDetail 移除 hero 图片并重排 filter；所有状态通过依赖注入 Mock。

**Tech Stack:** SwiftUI iOS17, @Observable/@StateObject, TabView(.page), AsyncImage + NSCache via Actor, NavigationStack, XCTest/XCUITest

**Spec:** Docs/BlocLens_MVP_PRD_v1.1.docx + 本次任务 3-17 节 + Docs/InformationArchitecture.md / NavigationContract.md / PageStateSpecification.md / MockArchitecture.md

## Global Constraints

- iPhone-only, iOS 17+, SwiftUI, 无第三方依赖, 无 AnyView, 无 force unwrap, Light/Dark, Dynamic Type, VoiceOver, Reduce Motion
- 源语言 en-AU, 保留 ko/zh-Hans, BundleID/Signing/Team/DeploymentTarget 不变, 图片二进制不入 Domain Model, 外链仅 URL
- 复用现有 Repository/DI/Mock, 无全局 Singleton, 图片最多4张, 按需加载可取消可重试, 缓存跨页面复用
- 复用现有 NavigationStack 与 Gym Detail destination, 不隐藏状态栏, 不用魔法数字 offset

---

## Task 1: GymPhotoLoader 抽象与缓存

**Files:**
- Create: `BlocLens/Core/Services/GymPhotoLoader.swift`
- Modify: `BlocLens/App/AppEnvironment.swift`

**Interfaces:**
- Consumes: GooglePlacesClient, GymPhoto
- Produces: protocol GymPhotoLoader { func loadPhoto(placeID:String, index:Int, width:Int) async throws -> GymPhoto; func photoCount(placeID:String) async throws -> Int? } ; actor GymPhotoCache

- [ ] Step 1: 写失败测试 `BlocLensTests/GymPhotoLoaderTests.swift` 覆盖：最多4张、不重复、按需加载、去重、取消、缓存复用、重试
- [ ] Step 2: 运行测试确认失败
- [ ] Step 3: 实现 GymPhotoLoader 协议、RemoteGymPhotoLoader(解析 photos.name 数组取 index, 缓存 photoNames, 单图 media fetch, 限制4), MockGymPhotoLoader(记录请求计数、支持失败注入、可配置每 placeID 数量), GymPhotoCache Actor(存 details + GymPhoto + inFlight Tasks, 取消支持)
- [ ] Step 4: 运行测试通过
- [ ] Step 5: Commit

## Task 2: 可复用 GymPhotoCarousel 组件

**Files:**
- Create: `BlocLens/Core/Components/GymPhotoCarouselView.swift`
- Create: `BlocLens/Core/Components/GymPhotoCarouselViewModel.swift` (或合一)

**Interfaces:**
- Consumes: GymPhotoLoader
- Produces: GymPhotoCarouselView(placeID: String?, gymName: String, loader: GymPhotoLoader)

- [ ] Step 1: 写 failing UI 逻辑测试：单图隐藏 indicator, 4图 indicator, 空状态 placeholder, Error 可重试按钮, 只有滑动才请求下一图
- [ ] Step 2: 运行确认失败
- [ ] Step 3: 实现 carousel：iOS17 TabView paging (或 ScrollView + .scrollTargetBehavior(.paging)), @State selectedIndex, onChange 触发 viewModel.loadIfNeeded(index), TabView 中每页按 state 显示 Loading/Loaded/Error/Empty, PageIndicator 仅>1时显示, 尊重 reduceMotion(禁用动画), AsyncImage 或 loader 返回 URL, 注入 loader, 固定 aspectRatio/cornerRadius 透参, Task 取消在 onDisappear
- [ ] Step 4: 运行测试通过

## Task 3: Home Safe Area 修复

**Files:**
- Modify: `BlocLens/Features/Home/HomeView.swift`

**Interfaces:**
- Consumes: NavigationStack safe area
- Produces: 无

- [ ] 检查当前 `ignoresSafeArea` 负 padding overlay 导致遮挡的根因
- [ ] 移除 Home dashboard 的 `.ignoresSafeArea(edges:.top)` 与魔法 `safeAreaPadding(.top,8)`, 改用 NavigationStack 原生 safeArea，在 ScrollView 内用 `.padding(.top, DesignSpacing.medium)` 保证不重叠状态栏，验证 iPhone SE / Pro / DynamicIsland
- [ ] 写 UI Test 单测 SafeArea
- [ ] 在模拟器验证 Light/Dark

## Task 4: Gym Name 自适应与导航

**Files:**
- Modify: `BlocLens/Features/Home/HomeView.swift`
- Modify: `BlocLens/Utilities/L10n.swift` 若需新增文案

**Interfaces:**
- Consumes: Gym.brandName, suburb, state
- Produces: GymNameTitleView

- [ ] 写测试：单行完整 name，当宽度不足回退 brandName+suburb 两行，最多2行，不用字符串拆分，ViewModel 逻辑 `displayNameLines(for gym, width, dynamicType)` 或 View 布局测试
- [ ] 实现：创建 `GymNameHeaderView` 或在 Home 顶部用 `ViewThatFits`/`GeometryReader` 判断：优先 Text(gym.name) single line, fallback VStack(Text(brandName), Text(suburb))，使用 brandName/suburb 结构化字段，设置 `lineLimit 1/2`，按钮整块可点击 NavigationLink(value:gym)，minHeight 44, accessibilityLabel "Open \(gym.name)", button trait, 字体 title2.bold -> 适度增大至 title.weight(.bold) 但不过夸张
- [ ] 验证 DynamicType 与截断

## Task 5: Home 图片区域替换

**Files:**
- Modify: `BlocLens/Features/Home/HomeView.swift`

**Interfaces:**
- Consumes: GymPhotoCarouselView
- Produces: 更新 currentGymHero

- [ ] 将 currentGymHero 中的单 GymPhotoView 替换为 GymPhotoCarouselView，保留 aspect 4/3、圆角 container、Community/Reset 胶囊 overlay，点击与滑动不冲突（Carousel 内图片可点击 via NavigationLink 但滑动优先，用 simultaneousGesture 处理）
- [ ] 确保初始只加载 index0
- [ ] Preview: 1张/4张/loading/error/empty

## Task 6: GymDetail 顶部层级重排 + Brand+Facilities 同行

**Files:**
- Modify: `BlocLens/Features/Gym/GymDetailView.swift`

**Interfaces:**
- Consumes: GymPhotoCarouselView, FacilityStatusView
- Produces: 顶部顺序 GymName > Brand+Facilities > Carousel > WallZoneDirectory

- [ ] 重排 heroPhotoSection 之前顺序：先 titleGroup(Gym Name) -> brandFacilitiesRow -> carousel -> wallZonesAndRoutesSection...
- [ ] brandFacilitiesRow: HStack{ Text(brandName).font(supporting).foreground(textSecondary); Spacer; FacilityIconsRow } ，小屏用 ViewThatFits 换行但保持顺序，icons 间距自适应，不溢出
- [ ] 写测试验证顺序

## Task 7: Facilities Icons 状态

**Files:**
- Create: `BlocLens/Core/Components/FacilityStatusView.swift` (或在 GymDetail 内)
- Modify: `BlocLens/Core/Models/Gym.swift` 若需 Unknown 支持

**Interfaces:**
- Consumes: Gym.facilities
- Produces: FacilityAvailability enum {available, unavailable, unknown}, FacilityIconView

- [ ] 定义映射：GymFacilityStatusProvider: facilities 包含 => available, 否则若固定全集 [parking,cafe,showers] 未包含 => unavailable, 若未来扩展支持 unknown 用 optional 或显式 FacilityAvailability 字典
- [ ] 每个 icon 圆形容器：available 绿色边框+绿色 icon+checkmark, unavailable 红色+xmark, unknown 灰色+questionmark, 使用 DesignColour tokens, 44pt 点击区域但非 Button, accessibilityLabel 如 "Parking available"
- [ ] 移除原独立 FacilitiesSection, 保留校验无第二 FacilitiesSection
- [ ] Preview: Available/Unavailable/Unknown, Light/Dark

## Task 8: GymDetail 图片轮播 + 重复信息清理 + Search 移除

**Files:**
- Modify: `BlocLens/Features/Gym/GymDetailView.swift`

**Interfaces:**
- Consumes: GymPhotoCarouselView
- Produces: 清理后 layout

- [ ] 将 heroPhotoSection 单图替换为 GymPhotoCarouselView (与 Home 共用 loader)
- [ ] 删除 compactMetadataRow 摘要 (brand · location · zones · beta · hardSoft) 及其下方长 Divider、7 Zones/1 Beta/Not enough data 相关文本、以及失去作用的容器/padding/spacer，确保无大块空白
- [ ] 删除 Search 相关：检查 GymDetail 是否有 searchBar，若有移除 @State searchText, filtered 逻辑, SearchField view, 仅移除该页面使用不删共享组件
- [ ] 重整间距：删除后 sections 间距统一 DesignSpacing.medium / sectionGap，避免双重 padding

## Task 9: Zone Detail 精简与筛选器重排

**Files:**
- Modify: `BlocLens/Features/WallZone/WallZoneRouteListView.swift`
- Modify: `BlocLens/Features/WallZone/WallZoneRouteListViewModel.swift`

**Interfaces:**
- Consumes: RouteListPresentation
- Produces: filterBar 顺序 HasBeta -> AllGrades -> Newest

- [ ] 标题：navigationTitle 从 wallZone.name 改为 "Zone Detail" (LocalizedStringResource), 主体顶部新增 WallHeaderInfo: HStack{ Text(wallZone.name).bold ; StatusChip(active/inactive) 带文字+icon 非仅颜色 ; Text(resetText) } 小屏换行但顺序 WallName -> Active -> Reset, 使用绿色/红色语义
- [ ] 删除 heroPhotoSection 整个 ZStack(height 4/3)、wallBaseColor、wallKindCapsuleSolid、Regular set wall 相关文字、长分隔线、蓝色 WallType 文字与 icon、及其布局代码
- [ ] 删除 compactMetadataRow 中蓝色 wallKind 文字？保留必要但移除 WallType 前 icon，按要求删除蓝色 Wall Type 与 icon 及对应 Divider
- [ ] filterBar 重排：ScrollView HStack 内顺序 Toggle HasBeta(带 checkmark/xmark 非仅颜色) -> Menu All Grades -> Menu Newest；HasBeta 激活用 icon+选中态，Grade/Sort 用 Menu Picker 默认 All Grades/Newest，保留逻辑；小屏自适应 Flow 但阅读顺序不变；提供 VoiceOver label/value/trait，44pt
- [ ] 移除 .searchable 修饰及其 onChange query 逻辑中对应部分？保留但要求删除 search? 任务说不影响 Wall Zone Route Search —— WallZone 的 searchable 是合法的，需保留，但 GymDetail 的 search 要删；确认 filterBar 不依赖 query search 保留
- [ ] 确保 spacing 重整无重复卡片

## Task 10: Tests、Previews、Build 与 Simulator 验证

**Files:**
- Test: `BlocLensTests/GymPhotoCarouselTests.swift` etc 已在前面创建
- Modify: `BlocLensUITests/BlocLensUITests.swift` 或新增 `GymZoneRefineUITests.swift`

**Interfaces:**
- Consumes: 以上所有
- Produces: 通过的测试与截图

- [ ] 全量 Unit Tests: 22 项覆盖清单 (图片数量/去重/懒加载/取消/缓存等, GymName, Facilities, Filters)
- [ ] UI Tests: 31 项覆盖清单 (SafeArea, GymName 导航, 滑动, Facilities 同行等)
- [ ] Previews: 覆盖 Home 1/4/loading/error/empty/单双行, GymDetail 4图+3种 facilities, ZoneDetail Active/Inactive, Light/Dark, 小屏, DynamicType
- [ ] Build: xcodebuild -scheme BlocLens -destination iPhone模拟器
- [ ] Simulator 验证：iPhone 16 Pro + iPhone SE, Light/Dark, 大字体, ReduceMotion, 路径 1-27
- [ ] Ponytail 复审：SafeArea、触控44pt、无障碍、状态非仅颜色、冗余空白
- [ ] Taste 复审：信息层级、间距、圆角、状态色、是否克制工具感
- [ ] 根据复审各至少一次修正 + 重新 Build/Test
- [ ] verification-before-completion: Build, Unit, UI, Git diff, iOS17 availability
- [ ] 创建本地 checkpoint commit `feat: refine gym and zone browsing` 不 Push

