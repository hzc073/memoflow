function memoflowCapture() {
  const normalize = (value) => {
    if (typeof value !== 'string') {
      return null;
    }
    const normalized = value.replace(/\s+/g, ' ').trim();
    return normalized.length > 0 ? normalized : null;
  };

  const readMeta = (selectors) => {
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      const content = normalize(element && element.getAttribute('content'));
      if (content) {
        return content;
      }
    }
    return null;
  };

  const readText = (selectors) => {
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      const text = normalize(element && element.textContent);
      if (text) {
        return text;
      }
    }
    return null;
  };

  const readAttributeUrl = (selectors, attributes) => {
    const resolvedAttributes =
      Array.isArray(attributes) && attributes.length > 0 ? attributes : ['href'];
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      if (!element || typeof element.getAttribute !== 'function') continue;
      for (const attribute of resolvedAttributes) {
        const url = toAbsoluteUrl(element.getAttribute(attribute));
        if (url) {
          return url;
        }
      }
    }
    return null;
  };

  const readImageUrl = (selectors, options) => {
    const excludePatterns =
      options && Array.isArray(options.excludePatterns)
        ? options.excludePatterns.map((item) => String(item || '').toLowerCase())
        : [];
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      if (!element) continue;
      const candidates = [
        readWechatImageCandidate(element),
        element.getAttribute && element.getAttribute('data-headimg'),
      ];
      for (const candidate of candidates) {
        const url = toAbsoluteUrl(candidate);
        if (!url) continue;
        const lower = url.toLowerCase();
        if (excludePatterns.some((pattern) => pattern && lower.includes(pattern))) {
          continue;
        }
        return url;
      }
    }
    return null;
  };

  const readWindowString = (keys) => {
    for (const key of keys) {
      try {
        const value = window[key];
        const normalized = normalize(typeof value === 'string' ? value : null);
        if (normalized) {
          return normalized;
        }
      } catch (_) {}
    }
    return null;
  };

  const toAbsoluteUrl = (value) => {
    const normalized = normalize(value);
    if (!normalized) {
      return null;
    }
    try {
      return new URL(normalized, location.href).toString();
    } catch (_) {
      return normalized;
    }
  };

  const sanitizeWechatImageUrl = (value) => {
    const absolute = toAbsoluteUrl(value);
    if (!absolute) {
      return null;
    }

    let sanitized = absolute
      .replace(/&amp;/gi, '&')
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/#imgIndex=\d+.*$/i, '');

    try {
      const parsed = new URL(sanitized, location.href);
      if (/^imgindex=/i.test(String(parsed.hash || '').replace(/^#/, ''))) {
        parsed.hash = '';
      }
      if (parsed.protocol === 'http:' && /\.?qpic\.cn$/i.test(parsed.hostname)) {
        parsed.protocol = 'https:';
      }
      sanitized = parsed.toString();
    } catch (_) {}

    return sanitized;
  };

  const readWechatImageCandidate = (element) => {
    if (!element) {
      return null;
    }

    const dataset = element.dataset || {};
    const candidates = [
      element.getAttribute && element.getAttribute('data-src'),
      element.getAttribute && element.getAttribute('data-lazy-src'),
      element.getAttribute && element.getAttribute('data-actualsrc'),
      element.getAttribute && element.getAttribute('data-original'),
      element.getAttribute && element.getAttribute('data-backsrc'),
      element.getAttribute && element.getAttribute('data-url'),
      element.getAttribute && element.getAttribute('data-imgsrc'),
      element.getAttribute && element.getAttribute('data-origin-src'),
      element.getAttribute && element.getAttribute('data-cover'),
      element.getAttribute && element.getAttribute('_src'),
      element.getAttribute && element.getAttribute('srcs'),
      dataset.src,
      dataset.lazySrc,
      dataset.actualsrc,
      dataset.original,
      dataset.backsrc,
      dataset.url,
      dataset.imgsrc,
      dataset.originSrc,
      dataset.cover,
      element.currentSrc,
      element.getAttribute && element.getAttribute('src'),
    ];
    let fallbackUrl = null;
    for (const candidate of candidates) {
      const url = sanitizeWechatImageUrl(candidate);
      if (url) {
        const lower = url.toLowerCase();
        if (
          lower.startsWith('data:') ||
          lower.startsWith('blob:') ||
          lower.startsWith('about:')
        ) {
          fallbackUrl = fallbackUrl || url;
          continue;
        }
        return url;
      }
    }
    return fallbackUrl;
  };

  const collectJsonScripts = () => {
    const blocks = [];
    for (const element of document.querySelectorAll('script[type="application/ld+json"]')) {
      const content = normalize(element.textContent || '');
      if (!content) continue;
      try {
        blocks.push(JSON.parse(content));
      } catch (_) {}
    }
    return blocks;
  };

  const collectBootstrapStates = () => {
    const keys = [
      '__playinfo__',
      '__INITIAL_STATE__',
      '__INITIAL_SSR_STATE__',
    ];
    const result = {};
    for (const key of keys) {
      try {
        const value = window[key];
        if (value !== undefined && value !== null) {
          result[key] = value;
        }
      } catch (_) {}
    }

    const extra = [];
    for (const element of document.querySelectorAll('script')) {
      const content = element.textContent || '';
      if (!content) continue;
      if (content.includes('INITIAL_STATE') || content.includes('note') || content.includes('playurl')) {
        extra.push(content.slice(0, 12000));
      }
    }
    return { windowStates: result, bootstrapStates: extra };
  };

  const rawVideoHints = [];
  const pushVideoHint = (hint) => {
    if (!hint || !hint.url) return;
    rawVideoHints.push(hint);
  };

  const classifyVideoUrl = (url) => {
    if (!url) return { direct: false, unsupported: false };
    const lower = url.toLowerCase();
    if (lower.startsWith('blob:') || lower.startsWith('data:')) {
      return { direct: false, unsupported: true };
    }
    if (lower.includes('.m3u8') || lower.includes('.m3u') || lower.includes('.mpd')) {
      return { direct: false, unsupported: true };
    }
    if (
      lower.includes('.mp4') ||
      lower.includes('.webm') ||
      lower.includes('.mov') ||
      lower.includes('.m4v') ||
      lower.includes('.mkv') ||
      lower.includes('.avi')
    ) {
      return { direct: true, unsupported: false };
    }
    return { direct: false, unsupported: false };
  };

  const collectVideoHints = () => {
    const metaSelectors = [
      'meta[property="og:video"]',
      'meta[property="og:video:url"]',
      'meta[property="og:video:secure_url"]',
      'meta[name="twitter:player:stream"]',
    ];
    for (const selector of metaSelectors) {
      const element = document.querySelector(selector);
      const url = toAbsoluteUrl(element && element.getAttribute('content'));
      if (!url) continue;
      const status = classifyVideoUrl(url);
      pushVideoHint({
        url,
        source: 'meta',
        mimeType: null,
        isDirectDownloadable: status.direct,
        reason: status.unsupported ? 'stream_only_not_supported' : null,
      });
    }

    for (const element of document.querySelectorAll('video')) {
      const directUrl = toAbsoluteUrl(element.getAttribute('src'));
      if (directUrl) {
        const status = classifyVideoUrl(directUrl);
        pushVideoHint({
          url: directUrl,
          source: 'dom',
          mimeType: element.getAttribute('type') || null,
          title: normalize(element.getAttribute('title')),
          isDirectDownloadable: status.direct,
          reason: status.unsupported ? 'stream_only_not_supported' : null,
        });
      }
      for (const source of element.querySelectorAll('source')) {
        const sourceUrl = toAbsoluteUrl(source.getAttribute('src'));
        if (!sourceUrl) continue;
        const status = classifyVideoUrl(sourceUrl);
        pushVideoHint({
          url: sourceUrl,
          source: 'dom',
          mimeType: source.getAttribute('type') || null,
          title: normalize(element.getAttribute('title')),
          isDirectDownloadable: status.direct,
          reason: status.unsupported ? 'stream_only_not_supported' : null,
        });
      }
    }

    for (const element of document.querySelectorAll('link[rel="preload"][as="video"]')) {
      const url = toAbsoluteUrl(element.getAttribute('href'));
      if (!url) continue;
      const status = classifyVideoUrl(url);
      pushVideoHint({
        url,
        source: 'link',
        mimeType: element.getAttribute('type') || null,
        isDirectDownloadable: status.direct,
        reason: status.unsupported ? 'stream_only_not_supported' : null,
      });
    }

    for (const element of document.querySelectorAll('a[href]')) {
      const href = toAbsoluteUrl(element.getAttribute('href'));
      if (!href) continue;
      const status = classifyVideoUrl(href);
      if (!status.direct && !status.unsupported) continue;
      pushVideoHint({
        url: href,
        source: 'link',
        title: normalize(element.textContent || ''),
        isDirectDownloadable: status.direct,
        reason: status.unsupported ? 'stream_only_not_supported' : null,
      });
    }

    for (const block of collectJsonScripts()) {
      const nodes = Array.isArray(block) ? block : [block];
      for (const node of nodes) {
        if (!node || typeof node !== 'object') continue;
        const typeValue = String(node['@type'] || node.type || '').toLowerCase();
        if (!typeValue.includes('videoobject')) continue;
        const url = toAbsoluteUrl(node.contentUrl || node.embedUrl || node.url);
        if (!url) continue;
        const status = classifyVideoUrl(url);
        pushVideoHint({
          url,
          source: 'jsonld',
          title: normalize(node.name || node.headline || ''),
          isDirectDownloadable: status.direct,
          reason: status.unsupported ? 'stream_only_not_supported' : null,
        });
      }
    }
  };

  const fallbackText = () => {
    const root = document.body || document.documentElement;
    return normalize(root && root.innerText ? root.innerText : '');
  };

  const collectWechatContentRoots = () => {
    const collectBySelectors = (selectors) => {
      const roots = [];
      const seen = new Set();
      for (const selector of selectors) {
        for (const element of document.querySelectorAll(selector)) {
          if (!element || seen.has(element)) continue;
          seen.add(element);
          roots.push(element);
        }
      }
      return roots;
    };

    const preferredRoots = collectBySelectors([
      '#js_content',
      '.rich_media_content',
    ]);
    if (preferredRoots.length > 0) {
      return preferredRoots;
    }

    return collectBySelectors([
      '#img-content',
      '.rich_media_area_primary_inner',
      '.rich_media_wrp',
    ]);
  };

  const scoreWechatContentRoot = (element) => {
    if (!element) {
      return -1;
    }

    const textLength = (normalize(element.innerText || '') || '').length;
    const htmlLength =
      typeof element.innerHTML === 'string' ? element.innerHTML.length : 0;
    const imageCount = element.querySelectorAll('img').length;
    const lazyImageCount = element.querySelectorAll(
      'img[data-src],img[data-lazy-src],img[data-actualsrc],img[data-original],img[data-backsrc],img[data-url],img[data-imgsrc],img[data-origin-src],img[_src],img[srcs]'
    ).length;
    const paragraphCount = element.querySelectorAll('p').length;

    return (
      imageCount * 20000 +
      lazyImageCount * 12000 +
      paragraphCount * 300 +
      textLength +
      Math.floor(htmlLength / 10)
    );
  };

  const selectWechatContentRoot = () => {
    const candidates = collectWechatContentRoots();
    if (candidates.length === 0) {
      return null;
    }

    candidates.sort((left, right) => {
      return scoreWechatContentRoot(right) - scoreWechatContentRoot(left);
    });
    return candidates[0];
  };

  const serializeWechatContentRoot = (element) => {
    if (!element) {
      return null;
    }

    const clone = element.cloneNode(true);
    normalizeCapturedImages(clone);

    const html =
      typeof clone.innerHTML === 'string' ? clone.innerHTML.trim() : '';
    return html.length > 0 ? html : null;
  };

  const normalizeCapturedImages = (root) => {
    if (!root || typeof root.querySelectorAll !== 'function') {
      return;
    }

    for (const image of root.querySelectorAll('img')) {
      const resolved = readWechatImageCandidate(image);
      if (resolved) {
        image.setAttribute('src', resolved);
      }
      for (const attribute of [
        'data-src',
        'data-lazy-src',
        'data-actualsrc',
        'data-original',
        'data-backsrc',
        'data-url',
        'data-imgsrc',
        'data-origin-src',
        'data-cover',
        '_src',
        'srcs',
      ]) {
        image.removeAttribute(attribute);
      }
    }
  };

  const serializeCoolapkContentRoot = (element) => {
    if (!element) {
      return null;
    }

    const clone = document.createElement('div');
    let appendedCount = 0;
    for (const selector of [
      '.feed-message',
      '.message-image-group',
      '.message-video-group',
      '.feed-link-url',
    ]) {
      for (const node of element.querySelectorAll(selector)) {
        clone.appendChild(node.cloneNode(true));
        appendedCount += 1;
      }
    }

    if (appendedCount === 0) {
      clone.appendChild(element.cloneNode(true));
    }
    normalizeCapturedImages(clone);

    const html =
      typeof clone.innerHTML === 'string' ? clone.innerHTML.trim() : '';
    return html.length > 0 ? html : null;
  };

  const isWechatMp = /(^|\.)mp\.weixin\.qq\.com$/i.test(
    String(location && location.hostname ? location.hostname : '')
  );
  const isCoolapk = /(^|\.)coolapk\.com$/i.test(
    String(location && location.hostname ? location.hostname : '')
  );
  const wechatContentRoot = isWechatMp ? selectWechatContentRoot() : null;
  const wechatContentHtml = isWechatMp
    ? serializeWechatContentRoot(wechatContentRoot)
    : null;
  const wechatTextContent =
    wechatContentRoot && typeof wechatContentRoot.innerText === 'string'
      ? normalize(wechatContentRoot.innerText)
      : null;
  const wechatAccountName = isWechatMp
    ? readText([
        '#js_name',
        '.rich_media_meta_nickname',
        '#profileBt',
        '#js_wx_follow_nickname_small_font',
      ]) || readWindowString(['nickname'])
    : null;
  const wechatAuthor = isWechatMp
    ? readWindowString(['author']) ||
      readText([
        '#js_author_name',
        '.meta_content#js_author_name',
        '.rich_media_meta_link[rel="author"]',
      ])
    : null;
  const wechatAccountAvatar = isWechatMp
    ? toAbsoluteUrl(
        readWindowString([
          'round_head_img',
          'hd_head_img',
          'ori_head_img_url',
          'msg_cdn_url',
        ])
      ) ||
      readImageUrl(
        [
          '.profile_container .profile_avatar',
          '.profile_container .profile_meta_hd img',
          '.wx_profile_card_inner .profile_avatar',
          '.wx_profile_card_inner .profile_meta_hd img',
          '.account_nickname_inner img',
        ],
        { excludePatterns: ['qrcode', 'qr_code', '/qr', 'ticket='] }
      )
    : null;
  const wechatAuthorAvatar = isWechatMp
    ? toAbsoluteUrl(
        readWindowString(['author_head_img', 'authorHeadImg', 'authorAvatar'])
      ) ||
      readImageUrl(
        [
          '#js_author_avatar img',
          '.rich_media_meta.author img',
          '.rich_media_meta_link[rel="author"] img',
          '.author_avatar img',
        ],
        { excludePatterns: ['qrcode', 'qr_code', '/qr', 'ticket='] }
      )
    : null;
  const coolapkContentRoot = isCoolapk
    ? document.querySelector('#feed-detail')
    : null;
  const coolapkContentHtml = isCoolapk
    ? serializeCoolapkContentRoot(coolapkContentRoot)
    : null;
  const coolapkTextContent =
    coolapkContentRoot && typeof coolapkContentRoot.innerText === 'string'
      ? normalize(coolapkContentRoot.innerText)
      : null;
  const coolapkSiteName = isCoolapk
    ? readText([
        '#header-logo span:last-child',
        '.mobile-header-content .text-group .title',
      ]) || '\u9177\u5b89'
    : null;
  const coolapkSiteIconUrl = isCoolapk
    ? readImageUrl([
        '#header-logo img',
        '.mobile-header-content .left-part img',
        '#footer .footer-logo-box img',
      ]) ||
      readAttributeUrl(
        [
          'link[rel="icon"]',
          'link[rel="shortcut icon"]',
          'link[rel="apple-touch-icon"]',
          'link[rel="apple-touch-icon-precomposed"]',
        ],
        ['href']
      )
    : null;
  const coolapkAuthor = isCoolapk
    ? readText([
        '#feed-detail .username-item p',
        '#feed-detail .common-userinfo-group .username-item p',
      ])
    : null;
  const coolapkAuthorAvatar = isCoolapk
    ? readImageUrl([
        '#feed-detail .avatar-item img',
        '#feed-detail .common-userinfo-group .avatar-item img',
      ])
    : null;
  const coolapkLeadImageUrl = isCoolapk
    ? readImageUrl(['#feed-detail .message-image-group img'])
    : null;

  const ogTitle = readMeta([
    'meta[property="og:title"]',
    'meta[name="og:title"]',
    'meta[name="twitter:title"]'
  ]);
  const siteIconUrl = readAttributeUrl(
    [
      'link[rel="icon"]',
      'link[rel="shortcut icon"]',
      'link[rel="apple-touch-icon"]',
      'link[rel="apple-touch-icon-precomposed"]',
    ],
    ['href']
  );
  const siteName = readMeta([
    'meta[property="og:site_name"]',
    'meta[name="application-name"]'
  ]);
  const description = readMeta([
    'meta[name="description"]',
    'meta[property="og:description"]',
    'meta[name="twitter:description"]'
  ]);
  const leadImageUrl = readMeta([
    'meta[property="og:image"]',
    'meta[name="twitter:image"]'
  ]);

  let parsed = null;
  let error = null;
  try {
    const clonedDocument = document.cloneNode(true);
    parsed = new Readability(clonedDocument).parse();
  } catch (captureError) {
    error = String(
      captureError && captureError.message ? captureError.message : captureError
    );
  }

  collectVideoHints();
  const bootstrap = collectBootstrapStates();
  const structuredData = collectJsonScripts();
  const parsedText = normalize(parsed && parsed.textContent ? parsed.textContent : null);
  const textContent = parsedText || fallbackText();
  const contentHtml =
    parsed && typeof parsed.content === 'string' && parsed.content.trim().length > 0
      ? parsed.content
      : null;

  return {
    finalUrl: String(location && location.href ? location.href : ''),
    pageTitle: normalize(document.title),
    articleTitle: normalize(parsed && parsed.title ? parsed.title : ogTitle),
    siteName: normalize(parsed && parsed.siteName ? parsed.siteName : siteName),
    byline: normalize(parsed && parsed.byline ? parsed.byline : null),
    excerpt: normalize(parsed && parsed.excerpt ? parsed.excerpt : description),
    contentHtml: contentHtml,
    textContent: textContent,
    siteIconUrl: normalize(siteIconUrl),
    wechatContentHtml: wechatContentHtml,
    wechatTextContent: wechatTextContent,
    wechatAccountName: wechatAccountName,
    wechatAuthor: wechatAuthor,
    wechatAccountAvatar: normalize(wechatAccountAvatar),
    wechatAuthorAvatar: normalize(wechatAuthorAvatar),
    coolapkContentHtml: coolapkContentHtml,
    coolapkTextContent: coolapkTextContent,
    coolapkSiteName: normalize(coolapkSiteName),
    coolapkSiteIconUrl: normalize(coolapkSiteIconUrl),
    coolapkAuthor: normalize(coolapkAuthor),
    coolapkAuthorAvatar: normalize(coolapkAuthorAvatar),
    coolapkLeadImageUrl: normalize(coolapkLeadImageUrl),
    leadImageUrl: normalize(leadImageUrl),
    length: textContent ? textContent.length : 0,
    readabilitySucceeded: !!contentHtml,
    rawVideoHints: rawVideoHints,
    structuredData: structuredData,
    windowStates: bootstrap.windowStates,
    bootstrapStates: bootstrap.bootstrapStates,
    pageUserAgent: normalize(navigator.userAgent),
    error: error,
  };
}
