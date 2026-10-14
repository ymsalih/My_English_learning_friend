// Testler için sahte Firestore, Auth, istek/cevap ve yukarı akış nesneleri.

export function fakeDb(initial = {}, { failReads = false } = {}) {
  const docs = new Map(Object.entries(initial));
  let reads = 0;
  const ref = (path) => ({
    path,
    async get() {
      reads++;
      if (failReads) throw new Error('firestore unavailable');
      const data = docs.get(path);
      return { exists: data !== undefined, data: () => structuredClone(data) };
    },
    async create(data) {
      if (docs.has(path)) throw new Error('already exists');
      docs.set(path, structuredClone(data));
    },
  });
  return {
    docs,
    get reads() {
      return reads;
    },
    doc: (path) => ref(path),
    collection: (name) => ({ doc: (id) => ref(`${name}/${id}`) }),
    async runTransaction(fn) {
      const tx = {
        async get(r) {
          const data = docs.get(r.path);
          return { exists: data !== undefined, data: () => structuredClone(data) };
        },
        set(r, data) {
          docs.set(r.path, data);
        },
      };
      return fn(tx);
    },
  };
}

export function fakeAuth(tokens = {}) {
  return {
    async verifyIdToken(token) {
      const decoded = tokens[token];
      if (!decoded) throw new Error('invalid token');
      return decoded;
    },
  };
}

export function fakeReq({ method = 'POST', path = '/', token, body, query } = {}) {
  const headers = token ? { authorization: `Bearer ${token}` } : {};
  return {
    method,
    path,
    body,
    query: query ?? {},
    get: (name) => headers[name.toLowerCase()],
  };
}

export function fakeRes() {
  const res = {
    statusCode: 200,
    headers: {},
    chunks: [],
    body: undefined,
    ended: false,
    headersSent: false,
    status(code) {
      this.statusCode = code;
      return this;
    },
    set(name, value) {
      this.headers[name.toLowerCase()] = value;
      return this;
    },
    json(obj) {
      this.body = obj;
      this.headersSent = true;
      this.ended = true;
      return this;
    },
    send(body) {
      this.body = body;
      this.headersSent = true;
      this.ended = true;
      return this;
    },
    write(chunk) {
      this.chunks.push(Buffer.from(chunk).toString('utf8'));
      this.headersSent = true;
    },
    end() {
      this.ended = true;
      this.headersSent = true;
    },
  };
  return res;
}

/** Çağrıları kaydeden sahte fetch. */
export function fakeFetch(respond) {
  const calls = [];
  const fn = async (url, options = {}) => {
    calls.push({ url, options });
    return respond(url, options);
  };
  fn.calls = calls;
  return fn;
}

export function jsonResponse(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json; charset=UTF-8' },
  });
}

export function sseResponse(lines) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    start(controller) {
      for (const line of lines) controller.enqueue(encoder.encode(`data: ${line}\r\n\r\n`));
      controller.close();
    },
  });
  return new Response(stream, { status: 200, headers: { 'content-type': 'text/event-stream' } });
}

export const silentLogger = { error() {}, warn() {} };
