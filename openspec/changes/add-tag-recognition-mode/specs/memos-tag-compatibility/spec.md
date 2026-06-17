## MODIFIED Requirements

### Requirement: Content fallback extraction uses strict tag zones
当后端 tag payload 缺失、为空、陈旧，或本地-only memo 内容需要从正文推导 app-visible 标签时，app MUST use the active `TagRecognitionMode`。`memoflowStrict` MUST 只从严格标签区提取标签；严格标签区仅包含 memo 的首个和最后一个非空内容行，候选行 trim 后 MUST 以一个或多个空白分隔的 `#tag` token 开头。`memosCompatible` MUST 尽量复刻 Memos 后端 inline tag extraction，在 Markdown text 中识别正文、列表、句末标点前、中文、emoji、层级标签和数字 tag。普通正文中夹带的 `#...` 在 `memoflowStrict` 下 MUST NOT 被提取为 app-visible 标签。

#### Scenario: Strict first and last tag-zone lines are extracted
- **WHEN** active mode is `memoflowStrict`
- **AND** memo content has first non-empty line `#openwrt #build`, middle body text, and last non-empty line `#router`
- **THEN** fallback extraction MUST return `openwrt`, `build`, and `router`
- **AND** local tag storage, search, and statistics MUST reflect only those extracted tag paths when no backend tag payload is used for local visible tags

#### Scenario: Strict leading tag prefix with trailing prose is extracted
- **WHEN** active mode is `memoflowStrict`
- **AND** memo content has first or last non-empty line `#测试文本 测试文本`
- **THEN** fallback extraction MUST return `测试文本`
- **AND** the trailing prose `测试文本` MUST remain normal memo content

#### Scenario: Strict later prose hash after tag prefix is ignored
- **WHEN** active mode is `memoflowStrict`
- **AND** memo content has first or last non-empty line `#first text #ignored`
- **THEN** fallback extraction MUST return `first`
- **AND** fallback extraction MUST NOT include `ignored`

#### Scenario: Strict body prose hash is ignored
- **WHEN** active mode is `memoflowStrict`
- **AND** memo content contains ordinary prose such as `测试文本 #这是测试文本`
- **THEN** fallback extraction MUST NOT create `这是测试文本` as an app-visible tag
- **AND** the prose content MUST remain unchanged

#### Scenario: Strict middle body tag is ignored
- **WHEN** active mode is `memoflowStrict`
- **AND** memo content has a valid-looking `#middle-tag` only in a middle paragraph, list item, blockquote, or table cell
- **THEN** fallback extraction MUST NOT include `middle-tag`

#### Scenario: Strict non-zone first or last line is ignored
- **WHEN** active mode is `memoflowStrict`
- **AND** the first or last non-empty line contains prose plus a hash fragment such as `今天记录一下 #生活`
- **THEN** fallback extraction MUST NOT include `生活`

#### Scenario: Memos compatible inline prose tag is extracted
- **WHEN** active mode is `memosCompatible`
- **AND** memo content contains ordinary prose such as `今天记录一下 #生活`
- **THEN** fallback extraction MUST include `生活`

#### Scenario: Memos compatible punctuation and list tags are extracted
- **WHEN** active mode is `memosCompatible`
- **AND** memo content contains `This is important #urgent.` or `- Item #todo`
- **THEN** fallback extraction MUST include `urgent` and `todo`

#### Scenario: Memos compatible numeric and international tags are extracted
- **WHEN** active mode is `memosCompatible`
- **AND** memo content contains `Issue #123 #测试 #test🚀 #work/项目`
- **THEN** fallback extraction MUST include `123`, `测试`, `test🚀`, and `work/项目`

#### Scenario: Protected Markdown contexts remain ignored by both modes
- **WHEN** memo content contains code blocks, inline code, links, images, or URL fragments with `#...`
- **THEN** fallback extraction MUST NOT create tags from those protected contexts
- **AND** valid tags outside those protected contexts MUST still be extracted according to the active mode

#### Scenario: Remote tag payload follows active visible mode
- **WHEN** remote sync receives a memo with a non-empty backend `Memo.tags` payload
- **AND** active mode is `memosCompatible`
- **THEN** local visible tags MAY preserve or merge the backend tag payload with locally extracted compatible tags
- **WHEN** active mode is `memoflowStrict`
- **THEN** app-visible local tag storage, search, statistics, and tag display MUST use strict extraction as the visible authority
- **AND** backend-returned tags that are not present in strict tag zones MUST NOT appear as local visible tags solely because the backend returned them

### Requirement: Memo tag decoration follows strict tag zones
Memo HTML rendering MUST decorate clickable tag chips according to the active `TagRecognitionMode`。`memoflowStrict` MUST decorate only tags in strict tag-zone lines. `memosCompatible` MUST decorate inline tags in Markdown text using Memos-compatible tag recognition while still avoiding protected Markdown contexts.

#### Scenario: Strict prose hash is not decorated
- **WHEN** active mode is `memoflowStrict`
- **AND** memo content contains `测试文本 #这是测试文本`
- **THEN** rendered memo HTML MUST NOT wrap `#这是测试文本` with the memo tag decoration span

#### Scenario: Strict tag-zone line is decorated
- **WHEN** active mode is `memoflowStrict`
- **AND** memo content contains a strict tag-zone prefix such as `#openwrt #build body #ignored`
- **THEN** rendered memo HTML SHOULD decorate `#openwrt` and `#build` as memo tags
- **AND** rendered memo HTML MUST NOT decorate `#ignored`

#### Scenario: Memos compatible prose hash is decorated
- **WHEN** active mode is `memosCompatible`
- **AND** memo content contains `今天记录 #生活`
- **THEN** rendered memo HTML SHOULD decorate `#生活` as a memo tag

#### Scenario: Memos compatible protected hashes are not decorated
- **WHEN** active mode is `memosCompatible`
- **AND** memo content contains an inline code span, code block, link destination, image URL, or URL fragment with `#...`
- **THEN** rendered memo HTML MUST NOT decorate those protected hash fragments as memo tags

## ADDED Requirements

### Requirement: Tag recognition mode preserves modular boundaries
Tag recognition mode behavior MUST remain centralized in shared lower-layer tag seams and MUST NOT be reimplemented inside feature screens, widgets, or settings pages.

#### Scenario: UI consumes shared recognition behavior
- **WHEN** settings, memo rendering, compose UI, search UI, or tag pages need tag recognition behavior
- **THEN** they MUST call shared tag recognition helpers or receive shared derived tag data
- **AND** they MUST NOT implement mode-specific tag parsing in screen or widget files

#### Scenario: Lower layers do not depend on feature UI
- **WHEN** mode-aware extraction, reconciliation, search fallback, or maintenance code is added
- **THEN** lower layers such as `core`, `data`, `application`, and `state` MUST NOT add new imports from memo/settings feature UI files
