const jsonHeaders = {
  'content-type': 'application/json; charset=utf-8',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders(request) });
    }

    if (request.method !== 'POST') {
      return json({ error: 'Use POST.' }, 405, request);
    }

    try {
      requireEnv(env, [
        'FIREBASE_PROJECT_ID',
        'FIREBASE_WEB_API_KEY',
        'CLOUDINARY_CLOUD_NAME',
        'CLOUDINARY_API_KEY',
        'CLOUDINARY_API_SECRET',
      ]);

      const idToken = readBearerToken(request);
      if (!idToken) {
        return json({ error: 'Missing Firebase auth token.' }, 401, request);
      }

      const body = await request.json();
      const postId = typeof body.postId === 'string' ? body.postId.trim() : '';
      const requestedPublicId =
        typeof body.cloudinaryPublicId === 'string'
          ? body.cloudinaryPublicId.trim()
          : '';

      if (!postId) {
        return json({ error: 'Missing postId.' }, 400, request);
      }

      const uid = await lookupFirebaseUid(env, idToken);
      const post = await readPost(env, idToken, postId);
      if (!post) {
        return json({ error: 'Photo not found.' }, 404, request);
      }

      const uploadedBy = stringField(post, 'uploadedBy');
      if (uploadedBy !== uid) {
        return json({ error: 'Only the uploader can delete this photo.' }, 403, request);
      }

      const publicId = stringField(post, 'cloudinaryPublicId') || requestedPublicId;
      if (!publicId) {
        return json({ error: 'Photo has no Cloudinary public ID.' }, 400, request);
      }

      const cloudinaryResult = await destroyCloudinaryAsset(env, publicId);
      const result = cloudinaryResult.result;
      if (result !== 'ok' && result !== 'not found') {
        return json(
          { error: `Cloudinary delete failed: ${result || 'unknown error'}` },
          502,
          request,
        );
      }

      await deletePost(env, idToken, postId);

      return json(
        {
          cloudinaryDeleted: result === 'ok' || result === 'not found',
          firestoreDeleted: true,
          cloudinaryResult: result,
        },
        200,
        request,
      );
    } catch (error) {
      return json({ error: error.message || 'Delete failed.' }, 500, request);
    }
  },
};

function requireEnv(env, names) {
  const missing = names.filter((name) => !env[name]);
  if (missing.length > 0) {
    throw new Error(`Missing Worker secret(s): ${missing.join(', ')}`);
  }
}

function readBearerToken(request) {
  const header = request.headers.get('authorization') || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match ? match[1] : null;
}

async function lookupFirebaseUid(env, idToken) {
  const url = new URL('https://identitytoolkit.googleapis.com/v1/accounts:lookup');
  url.searchParams.set('key', env.FIREBASE_WEB_API_KEY);

  const response = await fetch(url, {
    method: 'POST',
    headers: jsonHeaders,
    body: JSON.stringify({ idToken }),
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error?.message || 'Firebase token validation failed.');
  }

  const uid = data.users?.[0]?.localId;
  if (!uid) {
    throw new Error('Firebase token validation failed.');
  }
  return uid;
}

async function readPost(env, idToken, postId) {
  const response = await firestoreFetch(env, idToken, `posts/${encodeURIComponent(postId)}`);
  if (response.status === 404) return null;
  if (!response.ok) {
    const data = await safeJson(response);
    throw new Error(data.error?.message || 'Could not read the photo record.');
  }
  return response.json();
}

async function deletePost(env, idToken, postId) {
  const response = await firestoreFetch(env, idToken, `posts/${encodeURIComponent(postId)}`, {
    method: 'DELETE',
  });

  if (!response.ok && response.status !== 404) {
    const data = await safeJson(response);
    throw new Error(data.error?.message || 'Could not delete the photo record.');
  }
}

function firestoreFetch(env, idToken, path, init = {}) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}` +
    `/databases/(default)/documents/${path}`;

  return fetch(url, {
    ...init,
    headers: {
      ...(init.headers || {}),
      authorization: `Bearer ${idToken}`,
    },
  });
}

function stringField(document, fieldName) {
  const value = document.fields?.[fieldName]?.stringValue;
  return typeof value === 'string' ? value : '';
}

async function destroyCloudinaryAsset(env, publicId) {
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const signature = await sha1Hex(
    `invalidate=true&public_id=${publicId}&timestamp=${timestamp}${env.CLOUDINARY_API_SECRET}`,
  );

  const form = new FormData();
  form.set('public_id', publicId);
  form.set('timestamp', timestamp);
  form.set('invalidate', 'true');
  form.set('api_key', env.CLOUDINARY_API_KEY);
  form.set('signature', signature);

  const response = await fetch(
    `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/image/destroy`,
    {
      method: 'POST',
      body: form,
    },
  );
  const data = await safeJson(response);

  if (!response.ok) {
    throw new Error(data.error?.message || 'Cloudinary delete failed.');
  }
  return data;
}

async function sha1Hex(value) {
  const encoded = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-1', encoded);
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch (_) {
    return {};
  }
}

function json(data, status, request) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...jsonHeaders,
      ...corsHeaders(request),
    },
  });
}

function corsHeaders(request) {
  const origin = request.headers.get('origin') || '*';
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'POST, OPTIONS',
    'access-control-allow-headers': 'authorization, content-type',
  };
}
