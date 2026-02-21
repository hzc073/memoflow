/**
 * MemoFlow Update Config Worker
 *
 * Main responsibilities:
 * 1) Resolve release assets by tag from the app repo.
 * 2) Update platform URLs and versions in update_config/manifest.json.
 * 3) Auto-create announcement file for the tag (id: yyyymmddHHMMSS + random 3 digits).
 * 4) Append announcement id to manifest.announcement_ids and set latest_announcement_id.
 * 5) Ensure idempotency by release tag (manifest.announcement_tag_index).
 *
 * Required secrets:
 * - UPDATE_TOKEN: shared secret used by GitHub Actions caller.
 * - GITHUB_TOKEN: GitHub PAT with repo content write permissions.
 *
 * Optional vars:
 * - DEFAULT_APP_REPO: e.g. "hzc073/memoflow"
 * - DEFAULT_CONFIG_REPO: e.g. "hzc073/memoflow"
 * - DEFAULT_CONFIG_BRANCH: e.g. "main"
 * - DEFAULT_MANIFEST_PATH: e.g. "update_config/manifest.json"
 * - DEFAULT_ANNOUNCEMENTS_DIR: e.g. "update_config/announcements"
 */

const MAX_RETRY = 3;

export default {
  async fetch(request, env) {
    try {
      if (request.method !== "POST") {
        return json({ error: "method_not_allowed" }, 405);
      }

      const token = request.headers.get("x-update-token") || "";
      if (!env.UPDATE_TOKEN || token !== env.UPDATE_TOKEN) {
        return json({ error: "unauthorized" }, 401);
      }
      if (!env.GITHUB_TOKEN) {
        return json({ error: "missing_github_token" }, 500);
      }

      const payload = await safeJson(request);
      const rawTag = String(payload?.tag || "").trim();
      if (!rawTag) {
        return json({ error: "missing_tag" }, 400);
      }
      const tag = rawTag.startsWith("v") ? rawTag : `v${rawTag}`;
      const version = tag.startsWith("v") ? tag.slice(1) : tag;

      const appRepo = String(
        payload?.app_repo || env.DEFAULT_APP_REPO || "hzc073/memoflow",
      ).trim();
      const configRepo = String(
        payload?.config_repo || env.DEFAULT_CONFIG_REPO || "hzc073/memoflow",
      ).trim();
      const branch = String(
        payload?.config_branch || env.DEFAULT_CONFIG_BRANCH || "main",
      ).trim();
      const manifestPath = String(
        payload?.manifest_path ||
          env.DEFAULT_MANIFEST_PATH ||
          "update_config/manifest.json",
      ).trim();
      const announcementsDir = String(
        payload?.announcements_dir ||
          env.DEFAULT_ANNOUNCEMENTS_DIR ||
          joinPath(dirName(manifestPath), "announcements"),
      ).trim();
      const defaultLang = String(payload?.announcement_lang || "en").trim() || "en";

      const release = await ghRequestJson(
        env,
        "GET",
        `https://api.github.com/repos/${appRepo}/releases/tags/${encodeURIComponent(tag)}`,
      );
      const assets = Array.isArray(release?.assets) ? release.assets : [];
      const androidUrl = findAssetUrl(assets, (name) => /\.apk$/i.test(name));
      const windowsUrl = findAssetUrl(
        assets,
        (name) => /(_setup\.exe$|\.msi$|windows.*\.exe$)/i.test(name),
      );

      const createdAnnouncementIds = [];

      for (let attempt = 1; attempt <= MAX_RETRY; attempt += 1) {
        const manifestContent = await getRepoJsonContent(
          env,
          configRepo,
          manifestPath,
          branch,
        );
        const manifest = manifestContent.data;
        const manifestBefore = JSON.stringify(manifest);

        const versionInfo = ensureObject(manifest, "version_info");
        const android = ensureObject(versionInfo, "android");
        const windows = ensureObject(versionInfo, "windows");
        const ios = ensureObject(versionInfo, "ios");

        const now = nowIso();
        const updatedPlatforms = [];

        if (androidUrl) {
          android.url = androidUrl;
          android.latest_version = version;
          android.publish_at = now;
          updatedPlatforms.push("android");
        }
        if (windowsUrl) {
          windows.url = windowsUrl;
          windows.latest_version = version;
          windows.publish_at = now;
          updatedPlatforms.push("windows");
        }
        if (ios && typeof ios === "object") {
          // Keep iOS version aligned when release tag is published, unless overridden elsewhere later.
          if (!stringValue(ios.latest_version)) {
            ios.latest_version = version;
          }
        }

        const tagIndex = ensureObject(manifest, "announcement_tag_index");
        const announcementIds = ensureIdArray(manifest, "announcement_ids");

        let announcementId = normalizeIdString(tagIndex[tag]);
        if (!announcementId) {
          announcementId = await findAnnouncementIdByTag({
            env,
            repo: configRepo,
            branch,
            announcementsDir,
            ids: announcementIds,
            tag,
          });
        }

        if (!announcementId) {
          const generatedId = generateAnnouncementId(tag, release);
          const announcementPath = joinPath(announcementsDir, `${generatedId}.json`);
          const announcementPayload = buildAnnouncementPayload({
            id: generatedId,
            tag,
            version,
            release,
            lang: defaultLang,
          });

          const created = await createAnnouncementIfMissing({
            env,
            repo: configRepo,
            branch,
            path: announcementPath,
            content: announcementPayload,
          });
          if (created) {
            createdAnnouncementIds.push(generatedId);
          }
          announcementId = generatedId;
        }

        tagIndex[tag] = announcementId;
        if (!announcementIds.includes(announcementId)) {
          announcementIds.push(announcementId);
        }
        manifest.latest_announcement_id = announcementId;

        const manifestAfter = JSON.stringify(manifest);
        if (manifestBefore === manifestAfter) {
          return json({
            ok: true,
            tag,
            app_repo: appRepo,
            config_repo: configRepo,
            manifest_path: manifestPath,
            announcement_id: announcementId,
            updated_platforms: updatedPlatforms,
            android_url: androidUrl,
            windows_url: windowsUrl,
            created_announcement_ids: createdAnnouncementIds,
            note: "no manifest changes",
          });
        }

        try {
          await putRepoJsonContent(
            env,
            configRepo,
            manifestPath,
            branch,
            `chore(update_config): auto-update ${tag}`,
            manifest,
            manifestContent.sha,
          );
          return json({
            ok: true,
            tag,
            app_repo: appRepo,
            config_repo: configRepo,
            manifest_path: manifestPath,
            announcement_id: announcementId,
            updated_platforms: updatedPlatforms,
            android_url: androidUrl,
            windows_url: windowsUrl,
            created_announcement_ids: createdAnnouncementIds,
          });
        } catch (err) {
          if (isConflictError(err) && attempt < MAX_RETRY) {
            continue;
          }
          throw err;
        }
      }

      return json({ error: "update_retry_exhausted" }, 500);
    } catch (err) {
      return json(
        {
          error: "unexpected_error",
          detail: err instanceof Error ? err.message : String(err),
        },
        500,
      );
    }
  },
};

function buildAnnouncementPayload({ id, tag, version, release, lang }) {
  const lines = parseReleaseLines(stringValue(release?.body));
  const today = nowDate();
  const title = stringValue(release?.name) || `Release Notes ${tag}`;
  return {
    id,
    release_tag: tag,
    version,
    date: today,
    title,
    show_when_up_to_date: false,
    contents: {
      [lang]: lines,
    },
    new_donor_ids: [],
    items: [
      {
        category: "improvement",
        contents: lines,
      },
    ],
  };
}

function parseReleaseLines(body) {
  const trimmed = body.trim();
  if (!trimmed) {
    return ["Update available."];
  }
  const lines = trimmed
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => line.replace(/^[-*]\s+/, ""))
    .filter((line) => !/^#+\s*$/.test(line));
  if (lines.length === 0) {
    return ["Update available."];
  }
  return lines.slice(0, 10);
}

async function findAnnouncementIdByTag({
  env,
  repo,
  branch,
  announcementsDir,
  ids,
  tag,
}) {
  // Reverse order to hit most recent announcements first.
  for (let i = ids.length - 1; i >= 0; i -= 1) {
    const id = ids[i];
    const path = joinPath(announcementsDir, `${id}.json`);
    try {
      const file = await getRepoJsonContent(env, repo, path, branch);
      const releaseTag = stringValue(file?.data?.release_tag);
      if (releaseTag === tag) {
        return id;
      }
    } catch (err) {
      if (isNotFoundError(err)) {
        continue;
      }
      throw err;
    }
  }
  return "";
}

async function createAnnouncementIfMissing({ env, repo, branch, path, content }) {
  try {
    await putRepoJsonContent(
      env,
      repo,
      path,
      branch,
      `chore(update_config): add announcement ${stringValue(content.id)}`,
      content,
      "",
    );
    return true;
  } catch (err) {
    if (isAlreadyExistsError(err)) {
      return false;
    }
    throw err;
  }
}

function ensureObject(obj, key) {
  const value = obj[key];
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value;
  }
  const next = {};
  obj[key] = next;
  return next;
}

function ensureIdArray(obj, key) {
  const raw = obj[key];
  const values = Array.isArray(raw) ? raw : [];
  const out = [];
  const seen = new Set();
  for (const value of values) {
    const id = normalizeIdString(value);
    if (!id) continue;
    if (seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  obj[key] = out;
  return out;
}

function normalizeIdString(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return String(Math.trunc(value));
  }
  if (typeof value === "string") {
    const v = value.trim();
    if (/^\d+$/.test(v)) return v;
  }
  return "";
}

function generateAnnouncementId(tag, release) {
  const d = resolveAnnouncementDate(release);
  const yyyy = d.getUTCFullYear();
  const MM = pad2(d.getUTCMonth() + 1);
  const dd = pad2(d.getUTCDate());
  const HH = pad2(d.getUTCHours());
  const mm = pad2(d.getUTCMinutes());
  const ss = pad2(d.getUTCSeconds());
  const rand = String(stableRand3(tag));
  return `${yyyy}${MM}${dd}${HH}${mm}${ss}${rand}`;
}

function resolveAnnouncementDate(release) {
  const candidate =
    stringValue(release?.published_at) ||
    stringValue(release?.created_at) ||
    "";
  if (candidate) {
    const parsed = new Date(candidate);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return new Date();
}

function stableRand3(tag) {
  const source = stringValue(tag) || "memo";
  let hash = 0;
  for (let i = 0; i < source.length; i += 1) {
    hash = ((hash * 31) + source.charCodeAt(i)) >>> 0;
  }
  return 100 + (hash % 900);
}

function pad2(v) {
  return String(v).padStart(2, "0");
}

function nowIso() {
  return new Date().toISOString();
}

function nowDate() {
  const d = new Date();
  return `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(d.getUTCDate())}`;
}

function stringValue(v) {
  return typeof v === "string" ? v.trim() : "";
}

function dirName(path) {
  const normalized = path.replace(/\\/g, "/");
  const idx = normalized.lastIndexOf("/");
  if (idx <= 0) return "";
  return normalized.slice(0, idx);
}

function joinPath(a, b) {
  if (!a) return b.replace(/^\/+/, "");
  return `${a.replace(/\/+$/, "")}/${b.replace(/^\/+/, "")}`;
}

function findAssetUrl(assets, predicate) {
  for (const asset of assets) {
    const name = stringValue(asset?.name);
    if (!name || !predicate(name)) continue;
    const url = stringValue(asset?.browser_download_url);
    if (url) return url;
  }
  return "";
}

async function safeJson(request) {
  try {
    return await request.json();
  } catch (_) {
    return {};
  }
}

async function getRepoJsonContent(env, repo, path, ref) {
  const url = `https://api.github.com/repos/${repo}/contents/${path}?ref=${encodeURIComponent(ref)}`;
  const resp = await ghRequestJson(env, "GET", url);
  const sha = stringValue(resp?.sha);
  const raw = decodeBase64Utf8(stringValue(resp?.content));
  const data = JSON.parse(raw);
  if (!data || typeof data !== "object") {
    throw new Error(`invalid_json_object: ${repo}/${path}`);
  }
  return { data, sha };
}

async function putRepoJsonContent(
  env,
  repo,
  path,
  branch,
  message,
  data,
  sha,
) {
  const url = `https://api.github.com/repos/${repo}/contents/${path}`;
  const body = {
    message,
    content: encodeBase64Utf8(JSON.stringify(data, null, 2) + "\n"),
    branch,
  };
  if (sha) {
    body.sha = sha;
  }
  return ghRequestJson(env, "PUT", url, body);
}

class GitHubApiError extends Error {
  constructor(status, statusText, data) {
    super(
      `github_api_error ${status} ${statusText}: ${JSON.stringify(
        data ?? {},
      )}`,
    );
    this.name = "GitHubApiError";
    this.status = status;
    this.data = data;
  }
}

function isConflictError(err) {
  return err instanceof GitHubApiError && (err.status === 409 || err.status === 422);
}

function isNotFoundError(err) {
  return err instanceof GitHubApiError && err.status === 404;
}

function isAlreadyExistsError(err) {
  if (!(err instanceof GitHubApiError)) return false;
  if (err.status !== 422) return false;
  const message = stringValue(err?.data?.message).toLowerCase();
  return message.includes("sha") || message.includes("already exists");
}

async function ghRequestJson(env, method, url, body) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "Content-Type": "application/json",
      "User-Agent": "memoflow-update-config-worker",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch (_) {
    data = { raw: text };
  }
  if (!res.ok) {
    throw new GitHubApiError(res.status, res.statusText, data);
  }
  return data;
}

function decodeBase64Utf8(input) {
  const sanitized = input.replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(sanitized), (c) => c.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

function encodeBase64Utf8(input) {
  const bytes = new TextEncoder().encode(input);
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
    },
  });
}
