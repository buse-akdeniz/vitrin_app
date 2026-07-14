import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createHash, randomUUID } from 'crypto';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', 'data');
const DB_PATH = path.join(DATA_DIR, 'db.json');
const AUTH_SALT = process.env.AUTH_SALT || 'vitrin-dev-salt';

function parsePositiveInt(value, fallback) {
  const n = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return n;
}

const OFFER_DAILY_LIMIT = parsePositiveInt(process.env.OFFER_DAILY_LIMIT, 20);
const URGENT_DEFAULT_HOURS = parsePositiveInt(process.env.URGENT_DEFAULT_HOURS, 24);
const URGENT_MAX_HOURS = parsePositiveInt(process.env.URGENT_MAX_HOURS, 72);
const LAUNCH_BOOST_DEFAULT_HOURS = parsePositiveInt(process.env.LAUNCH_BOOST_DEFAULT_HOURS, 72);
const LAUNCH_BOOST_MAX_HOURS = parsePositiveInt(process.env.LAUNCH_BOOST_MAX_HOURS, 168);
const COMMISSION_PERCENT = Number.parseFloat(process.env.COMMISSION_PERCENT || '4.9');
const PAYMENT_PERCENT = Number.parseFloat(process.env.PAYMENT_PERCENT || '2.99');
const PAYMENT_FIXED_TRY = Number.parseFloat(process.env.PAYMENT_FIXED_TRY || '1.5');

function isUrgentSaleActive(product) {
  const urgent = Boolean(product?.urgentSale ?? product?.urgent_sale);
  const untilRaw = product?.urgentUntil ?? product?.urgent_until;
  if (!urgent || !untilRaw) return false;
  const untilMs = new Date(untilRaw).getTime();
  return Number.isFinite(untilMs) && untilMs > Date.now();
}

function isLaunchBoostActive(product) {
  const boosted = Boolean(product?.launchBoost ?? product?.launch_boost);
  const untilRaw = product?.launchBoostUntil ?? product?.launch_boost_until;
  if (!boosted || !untilRaw) return false;
  const untilMs = new Date(untilRaw).getTime();
  return Number.isFinite(untilMs) && untilMs > Date.now();
}

function toUrgentUntil(hours) {
  const safeHours = Math.max(1, Math.min(URGENT_MAX_HOURS, Number(hours) || URGENT_DEFAULT_HOURS));
  return new Date(Date.now() + safeHours * 60 * 60 * 1000).toISOString();
}

function toLaunchBoostUntil(hours) {
  const safeHours = Math.max(1, Math.min(LAUNCH_BOOST_MAX_HOURS, Number(hours) || LAUNCH_BOOST_DEFAULT_HOURS));
  return new Date(Date.now() + safeHours * 60 * 60 * 1000).toISOString();
}

function normalizeCategory(value) {
  return String(value || '').trim().toLowerCase();
}

function categoryFamily(category) {
  const c = normalizeCategory(category);
  if (!c) return 'other';
  if (/(ceket|hırka|kazak|gömlek|bluz|tişört|tshirt|üst)/.test(c)) return 'top';
  if (/(pantolon|etek|şort|sort|alt|jean)/.test(c)) return 'bottom';
  if (/(elbise|tulum)/.test(c)) return 'dress';
  if (/(ayakkabı|ayakkabi|sneaker|bot|topuklu)/.test(c)) return 'shoe';
  if (/(çanta|canta|aksesuar|takı|taki|kemer)/.test(c)) return 'accessory';
  return 'other';
}

function isComplementaryCategory(base, candidate) {
  const a = categoryFamily(base);
  const b = categoryFamily(candidate);
  if (a === 'other' || b === 'other') return false;
  if (a === b && a !== 'accessory') return false;
  if (a === 'dress') return b === 'shoe' || b === 'accessory';
  if (a === 'top') return b === 'bottom' || b === 'shoe' || b === 'accessory';
  if (a === 'bottom') return b === 'top' || b === 'shoe' || b === 'accessory';
  if (a === 'shoe') return b === 'dress' || b === 'top' || b === 'bottom';
  return true;
}

function defaultDb() {
  return {
    nextUserId: 1,
    nextProductId: 1,
    nextOfferId: 1,
    nextOrderId: 1,
    nextNotificationId: 1,
    nextCommentId: 1,
    users: [],
    tokens: {},
    products: [],
    favorites: {},
    follows: {},
    offers: [],
    orders: [],
    notifications: [],
    comments: [],
    offerQuota: {},
  };
}

let db = null;

function hashPassword(password) {
  return createHash('sha256').update(`${AUTH_SALT}:${password}`).digest('hex');
}

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

export function loadDb() {
  if (db) return db;
  ensureDataDir();
  if (!fs.existsSync(DB_PATH)) {
    db = defaultDb();
    saveDb();
    return db;
  }
  try {
    const raw = fs.readFileSync(DB_PATH, 'utf8');
    db = { ...defaultDb(), ...JSON.parse(raw) };
  } catch {
    db = defaultDb();
    saveDb();
  }
  return db;
}

export function saveDb() {
  ensureDataDir();
  fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2));
}

export function createToken(userId) {
  loadDb();
  const token = randomUUID();
  db.tokens[token] = userId;
  saveDb();
  return token;
}

export function getUserIdFromToken(token) {
  if (!token) return null;
  loadDb();
  return db.tokens[token] ?? null;
}

export function findUserByEmail(email) {
  loadDb();
  const normalized = String(email || '').trim().toLowerCase();
  return db.users.find((u) => u.email === normalized) ?? null;
}

export function getUserById(userId) {
  loadDb();
  return db.users.find((u) => u.id === userId) ?? null;
}

export function createUser({ email, password }) {
  loadDb();
  const normalized = String(email || '').trim().toLowerCase();
  if (!normalized || !password) {
    return { ok: false, message: 'E-posta ve şifre zorunlu' };
  }
  if (findUserByEmail(normalized)) {
    return { ok: false, message: 'Bu e-posta zaten kayıtlı' };
  }
  const user = {
    id: db.nextUserId++,
    email: normalized,
    passwordHash: hashPassword(password),
    name: normalized.split('@')[0],
    bio: '',
    createdAt: new Date().toISOString(),
  };
  db.users.push(user);
  saveDb();
  return { ok: true, user };
}

export function verifyUser({ email, password }) {
  const user = findUserByEmail(email);
  if (!user) return { ok: false, message: 'E-posta veya şifre hatalı' };
  if (user.passwordHash !== hashPassword(password)) {
    return { ok: false, message: 'E-posta veya şifre hatalı' };
  }
  return { ok: true, user };
}

export function publicUser(user) {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    bio: user.bio,
  };
}

export function updateUserProfile(userId, { name, bio }) {
  loadDb();
  const user = db.users.find((u) => u.id === userId);
  if (!user) return null;
  if (name != null) user.name = String(name).trim().slice(0, 120);
  if (bio != null) user.bio = String(bio).trim().slice(0, 500);
  saveDb();
  return user;
}

export function listProducts({ q, sosOnly, smartMode } = {}) {
  loadDb();
  let items = [...db.products].sort((a, b) => {
    const boostDiff = Number(isLaunchBoostActive(b)) - Number(isLaunchBoostActive(a));
    if (boostDiff !== 0) return boostDiff;
    const urgentDiff = Number(isUrgentSaleActive(b)) - Number(isUrgentSaleActive(a));
    if (urgentDiff !== 0) return urgentDiff;
    return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
  });

  if (sosOnly) items = items.filter((p) => p.isSos);
  if (q) {
    const needle = String(q).trim().toLowerCase();
    items = items.filter((p) => {
      const hay = `${p.title} ${p.brand} ${p.category} ${p.description}`.toLowerCase();
      return hay.includes(needle);
    });
  }

  if (smartMode === '1' && items.length > 1) {
    items = items.slice().sort((a, b) => {
      const boostDiff = Number(isLaunchBoostActive(b)) - Number(isLaunchBoostActive(a));
      if (boostDiff !== 0) return boostDiff;
      const urgentDiff = Number(isUrgentSaleActive(b)) - Number(isUrgentSaleActive(a));
      if (urgentDiff !== 0) return urgentDiff;
      return (b.isSos ? 1 : 0) - (a.isSos ? 1 : 0);
    });
  }

  return items;
}

export function createProduct(sellerId, payload) {
  loadDb();
  const imageUrl = String(payload.imageUrl || '').trim();
  const urgentSale = Boolean(payload.urgentSale ?? payload.urgent_sale);
  const urgentUntil = urgentSale ? toUrgentUntil(payload.urgentHours) : null;
  const launchBoost = Boolean(payload.launchBoost ?? payload.launch_boost);
  const launchBoostUntil = launchBoost ? toLaunchBoostUntil(payload.launchBoostHours) : null;
  const product = {
    id: db.nextProductId++,
    sellerId,
    title: String(payload.title || '').trim().slice(0, 200),
    price: Number(payload.price) || 0,
    category: String(payload.category || '').trim(),
    brand: String(payload.brand || '').trim(),
    size: String(payload.size || '').trim(),
    fabricType: String(payload.fabricType || '').trim(),
    shoeSize: String(payload.shoeSize || '').trim(),
    gender: String(payload.gender || '').trim(),
    condition: String(payload.condition || '').trim(),
    shippingType: String(payload.shippingType || 'seller').trim(),
    packageSize: String(payload.packageSize || 'medium').trim(),
    color: String(payload.color || '').trim(),
    description: String(payload.description || '').trim(),
    isSos: Boolean(payload.isSos),
    sosDiscountPercent: Number(payload.sosDiscountPercent) || 0,
    image_url: imageUrl,
    imageUrl,
    image_variants: payload.imageVariants || payload.image_variants || null,
    image_status: imageUrl ? 'ready' : 'none',
    urgentSale,
    urgent_sale: urgentSale,
    urgentUntil,
    urgent_until: urgentUntil,
    launchBoost,
    launch_boost: launchBoost,
    launchBoostUntil,
    launch_boost_until: launchBoostUntil,
    sale_status: 'available',
    seller_id: sellerId,
    user_id: sellerId,
    package_size: String(payload.packageSize || 'medium').trim(),
    shipping_type: String(payload.shippingType || 'seller').trim(),
    item_condition: String(payload.condition || '').trim(),
    created_at: new Date().toISOString(),
  };

  if (imageUrl && !product.image_variants) {
    product.image_variants = {
      small: imageUrl,
      medium: imageUrl,
      large: imageUrl,
      original: imageUrl,
    };
  }

  db.products.unshift(product);
  saveDb();
  return product;
}

export function getFavoriteProductIds(userId) {
  loadDb();
  return db.favorites[String(userId)] ?? [];
}

export function addFavorite(userId, productId) {
  loadDb();
  const key = String(userId);
  const list = db.favorites[key] ?? [];
  if (!list.includes(productId)) list.push(productId);
  db.favorites[key] = list;
  saveDb();
  return list;
}

export function removeFavorite(userId, productId) {
  loadDb();
  const key = String(userId);
  const list = (db.favorites[key] ?? []).filter((id) => id !== productId);
  db.favorites[key] = list;
  saveDb();
  return list;
}

export function getProductsByIds(ids) {
  loadDb();
  const set = new Set(ids);
  return db.products.filter((p) => set.has(p.id));
}

export function formatProductForApi(product) {
  if (!product) return null;
  const urgentSale = Boolean(product.urgentSale ?? product.urgent_sale);
  const urgentUntil = product.urgentUntil ?? product.urgent_until ?? null;
  const launchBoost = Boolean(product.launchBoost ?? product.launch_boost);
  const launchBoostUntil = product.launchBoostUntil ?? product.launch_boost_until ?? null;
  return {
    ...product,
    seller_id: product.sellerId,
    user_id: product.sellerId,
    sale_status: product.sale_status ?? 'available',
    package_size: product.package_size ?? product.packageSize ?? 'medium',
    shipping_type: product.shipping_type ?? product.shippingType ?? 'seller',
    item_condition: product.item_condition ?? product.condition ?? '',
    image_variants: product.image_variants ?? product.imageVariants ?? null,
    imageVariants: product.image_variants ?? product.imageVariants ?? null,
    urgent_sale: urgentSale,
    urgentSale,
    urgent_until: urgentUntil,
    urgentUntil,
    is_urgent_active: urgentSale && Boolean(urgentUntil) && new Date(urgentUntil).getTime() > Date.now(),
    launch_boost: launchBoost,
    launchBoost,
    launch_boost_until: launchBoostUntil,
    launchBoostUntil,
    is_launch_boost_active:
      launchBoost && Boolean(launchBoostUntil) && new Date(launchBoostUntil).getTime() > Date.now(),
  };
}

export function getProductById(productId) {
  loadDb();
  const product = db.products.find((p) => p.id === productId);
  return product ?? null;
}

export function updateProduct(sellerId, productId, patch) {
  loadDb();
  const product = db.products.find((p) => p.id === productId && p.sellerId === sellerId);
  if (!product) return null;
  if (patch.title != null) product.title = String(patch.title).trim().slice(0, 200);
  if (patch.description != null) product.description = String(patch.description).trim().slice(0, 4000);
  if (patch.price != null) product.price = Number(patch.price);
  if (patch.shippingType != null) {
    product.shippingType = String(patch.shippingType);
    product.shipping_type = product.shippingType;
  }
  if (patch.packageSize != null) {
    product.packageSize = String(patch.packageSize);
    product.package_size = product.packageSize;
  }
  if (patch.saleStatus != null) {
    product.sale_status = String(patch.saleStatus);
  }
  if (patch.urgentSale != null) {
    const urgentSale = Boolean(patch.urgentSale);
    product.urgentSale = urgentSale;
    product.urgent_sale = urgentSale;
    const urgentUntil = urgentSale ? toUrgentUntil(patch.urgentHours) : null;
    product.urgentUntil = urgentUntil;
    product.urgent_until = urgentUntil;
  }
  if (patch.launchBoost != null) {
    const launchBoost = Boolean(patch.launchBoost);
    product.launchBoost = launchBoost;
    product.launch_boost = launchBoost;
    const launchBoostUntil = launchBoost ? toLaunchBoostUntil(patch.launchBoostHours) : null;
    product.launchBoostUntil = launchBoostUntil;
    product.launch_boost_until = launchBoostUntil;
  }
  saveDb();
  return product;
}

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

export function getOfferQuota(userId) {
  loadDb();
  const dailyLimit = OFFER_DAILY_LIMIT;
  const key = String(userId);
  const bucket = db.offerQuota[key];
  const used = bucket?.date === todayKey() ? bucket.count : 0;
  return { used, dailyLimit, remaining: Math.max(0, dailyLimit - used) };
}

export function getCommissionQuote({ amount, shippingType }) {
  const gross = Number(amount);
  if (!Number.isFinite(gross) || gross <= 0) {
    return { success: false, message: 'Geçersiz tutar' };
  }
  const commission = Math.max(0, (gross * COMMISSION_PERCENT) / 100);
  const paymentFee = Math.max(0, (gross * PAYMENT_PERCENT) / 100 + PAYMENT_FIXED_TRY);
  const payout = Math.max(0, gross - commission - paymentFee);
  return {
    success: true,
    amount: Number(gross.toFixed(2)),
    commissionPercent: COMMISSION_PERCENT,
    paymentPercent: PAYMENT_PERCENT,
    paymentFixedTry: PAYMENT_FIXED_TRY,
    commission: Number(commission.toFixed(2)),
    paymentFee: Number(paymentFee.toFixed(2)),
    estimatedPayout: Number(payout.toFixed(2)),
    shippingType: String(shippingType || 'seller').trim() || 'seller',
  };
}

export function getOutfitRecommendations(productId, { limit = 6 } = {}) {
  loadDb();
  const target = getProductById(productId);
  if (!target) return null;

  const targetPrice = Number(target.price) || 0;
  const targetGender = normalizeCategory(target.gender);
  const max = Math.max(1, Math.min(20, Number(limit) || 6));

  const candidates = db.products
    .filter((p) => p.id !== target.id)
    .filter((p) => (p.sale_status ?? 'available') === 'available')
    .filter((p) => isComplementaryCategory(target.category, p.category))
    .filter((p) => {
      if (!targetGender) return true;
      const g = normalizeCategory(p.gender);
      return !g || g === targetGender || g === 'unisex';
    })
    .map((p) => {
      const price = Number(p.price) || 0;
      const priceDelta = Math.abs(price - targetPrice);
      const urgentBoost = isUrgentSaleActive(p) ? 20 : 0;
      const score = Math.max(0, 100 - priceDelta / 10) + urgentBoost;
      return { p, score };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, max)
    .map(({ p }) => formatProductForApi(p));

  return {
    success: true,
    productId: target.id,
    recommendations: candidates,
  };
}

function incrementOfferQuota(userId) {
  loadDb();
  const key = String(userId);
  const date = todayKey();
  const bucket = db.offerQuota[key];
  if (!bucket || bucket.date !== date) {
    db.offerQuota[key] = { date, count: 1 };
  } else {
    bucket.count += 1;
  }
  saveDb();
}

function userName(userId) {
  const user = getUserById(userId);
  return user?.name || user?.email?.split('@')[0] || 'Kullanıcı';
}

function addNotification({ userId, title, message, data = {} }) {
  loadDb();
  const note = {
    id: db.nextNotificationId++,
    userId,
    title,
    message,
    data_json: JSON.stringify(data),
    is_read: 0,
    created_at: new Date().toISOString(),
  };
  db.notifications.unshift(note);
  saveDb();
  return note;
}

export function getNotifications(userId) {
  loadDb();
  return db.notifications.filter((n) => n.userId === userId);
}

export function getUnreadNotificationCount(userId) {
  return getNotifications(userId).filter((n) => !n.is_read).length;
}

export function markNotificationRead(userId, notificationId) {
  loadDb();
  const note = db.notifications.find((n) => n.id === notificationId && n.userId === userId);
  if (!note) return false;
  note.is_read = 1;
  saveDb();
  return true;
}

export function markAllNotificationsRead(userId) {
  loadDb();
  for (const note of db.notifications) {
    if (note.userId === userId) note.is_read = 1;
  }
  saveDb();
}

export function getFollowedSellers(userId) {
  loadDb();
  const ids = db.follows[String(userId)] ?? [];
  return ids.map((sellerId) => ({
    seller_id: sellerId,
    name: userName(sellerId),
  }));
}

export function followSeller(userId, sellerId) {
  loadDb();
  if (userId === sellerId) return { ok: false, message: 'Kendinizi takip edemezsiniz' };
  const key = String(userId);
  const list = db.follows[key] ?? [];
  if (!list.includes(sellerId)) list.push(sellerId);
  db.follows[key] = list;
  saveDb();
  return { ok: true, message: 'Satıcı takip edildi' };
}

export function unfollowSeller(userId, sellerId) {
  loadDb();
  const key = String(userId);
  db.follows[key] = (db.follows[key] ?? []).filter((id) => id !== sellerId);
  saveDb();
  return { ok: true, message: 'Takip bırakıldı' };
}

function formatOffer(offer) {
  const product = getProductById(offer.productId);
  return {
    id: offer.id,
    product_id: offer.productId,
    product_title: product?.title ?? '',
    amount: offer.amount,
    status: offer.status,
    buyer_id: offer.buyerId,
    seller_id: offer.sellerId,
    buyer_name: userName(offer.buyerId),
    seller_name: userName(offer.sellerId),
    created_at: offer.created_at,
  };
}

export function createOffer(buyerId, { productId, amount }) {
  loadDb();
  const product = getProductById(productId);
  if (!product) return { ok: false, message: 'Ürün bulunamadı' };
  if (product.sellerId === buyerId) return { ok: false, message: 'Kendi ürününüze teklif veremezsiniz' };
  if ((product.sale_status ?? 'available') !== 'available') {
    return { ok: false, message: 'Ürün teklife kapalı' };
  }

  const quota = getOfferQuota(buyerId);
  if (quota.used >= quota.dailyLimit) {
    return { ok: false, message: 'Günlük teklif limitine ulaştınız' };
  }

  const offer = {
    id: db.nextOfferId++,
    productId,
    buyerId,
    sellerId: product.sellerId,
    amount: Number(amount),
    status: 'pending',
    created_at: new Date().toISOString(),
    events: [
      {
        actorId: buyerId,
        actor_name: userName(buyerId),
        event_type: 'offer_created',
        amount: Number(amount),
        note: 'Teklif verildi',
        created_at: new Date().toISOString(),
      },
    ],
  };
  db.offers.unshift(offer);
  incrementOfferQuota(buyerId);
  addNotification({
    userId: product.sellerId,
    title: 'Yeni teklif',
    message: `${userName(buyerId)} ₺${amount} teklif verdi`,
    data: { offerId: offer.id, productId },
  });
  saveDb();
  return { ok: true, message: 'Teklif gönderildi', offer: formatOffer(offer) };
}

export function getSentOffers(userId) {
  loadDb();
  return db.offers.filter((o) => o.buyerId === userId).map(formatOffer);
}

export function getReceivedOffers(userId) {
  loadDb();
  return db.offers.filter((o) => o.sellerId === userId).map(formatOffer);
}

export function getOfferById(offerId) {
  loadDb();
  return db.offers.find((o) => o.id === offerId) ?? null;
}

export function respondOffer(userId, offerId, { action, counterAmount }) {
  loadDb();
  const offer = getOfferById(offerId);
  if (!offer) return { ok: false, message: 'Teklif bulunamadı' };

  const isSeller = offer.sellerId === userId;
  const isBuyer = offer.buyerId === userId;
  if (!isSeller && !isBuyer) return { ok: false, message: 'Yetkisiz işlem' };

  const pushEvent = (event) => {
    offer.events.push({
      ...event,
      created_at: new Date().toISOString(),
    });
  };

  if (action === 'accept') {
    if (isSeller && offer.status !== 'pending') {
      return { ok: false, message: 'Teklif artık kabul edilemez' };
    }
    if (isBuyer && offer.status !== 'countered') {
      return { ok: false, message: 'Karşı teklif kabul edilemez' };
    }
    offer.status = 'accepted';
    pushEvent({
      actorId: userId,
      actor_name: userName(userId),
      event_type: 'accepted',
      amount: offer.amount,
      note: 'Teklif kabul edildi',
    });
    createOrderFromOffer(offer);
    if (isSeller) {
      addNotification({
        userId: offer.buyerId,
        title: 'Teklif kabul edildi',
        message: `${userName(offer.sellerId)} teklifinizi kabul etti`,
        data: { offerId: offer.id, productId: offer.productId },
      });
    } else {
      addNotification({
        userId: offer.sellerId,
        title: 'Karşı teklif kabul edildi',
        message: `${userName(offer.buyerId)} karşı teklifinizi kabul etti`,
        data: { offerId: offer.id, productId: offer.productId },
      });
    }
    saveDb();
    return { ok: true, message: 'Teklif kabul edildi' };
  }

  if (action === 'reject') {
    offer.status = 'rejected';
    pushEvent({
      actorId: userId,
      actor_name: userName(userId),
      event_type: 'rejected',
      amount: offer.amount,
      note: 'Teklif reddedildi',
    });
    saveDb();
    return { ok: true, message: 'Teklif reddedildi' };
  }

  if (action === 'counter') {
    if (!isSeller || offer.status !== 'pending') {
      return { ok: false, message: 'Karşı teklif verilemez' };
    }
    const amount = Number(counterAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return { ok: false, message: 'Geçersiz tutar' };
    }
    offer.amount = amount;
    offer.status = 'countered';
    pushEvent({
      actorId: userId,
      actor_name: userName(userId),
      event_type: 'counter',
      amount,
      note: 'Karşı teklif verildi',
    });
    addNotification({
      userId: offer.buyerId,
      title: 'Karşı teklif',
      message: `${userName(offer.sellerId)} ₺${amount} karşı teklif verdi`,
      data: { offerId: offer.id, productId: offer.productId },
    });
    saveDb();
    return { ok: true, message: 'Karşı teklif gönderildi' };
  }

  return { ok: false, message: 'Geçersiz işlem' };
}

export function getOfferHistory(offerId, userId) {
  const offer = getOfferById(offerId);
  if (!offer) return null;
  if (offer.buyerId !== userId && offer.sellerId !== userId) return null;
  return offer.events ?? [];
}

function createOrderFromOffer(offer) {
  const product = getProductById(offer.productId);
  if (!product) return null;
  product.sale_status = 'reserved';

  const order = {
    id: db.nextOrderId++,
    productId: offer.productId,
    offerId: offer.id,
    buyerId: offer.buyerId,
    sellerId: offer.sellerId,
    amount: offer.amount,
    order_status: 'paid',
    tracking_no: '',
    shipping_type: product.shipping_type ?? product.shippingType ?? 'seller',
    package_size: product.package_size ?? product.packageSize ?? 'medium',
    product_title: product.title,
    seller_rating: 4.8,
    created_at: new Date().toISOString(),
    events: [
      {
        event_type: 'order_created',
        note: 'Sipariş oluşturuldu',
        created_at: new Date().toISOString(),
      },
    ],
  };
  db.orders.unshift(order);
  addNotification({
    userId: offer.buyerId,
    title: 'Sipariş oluşturuldu',
    message: `Sipariş #${order.id} oluşturuldu`,
    data: { orderId: order.id },
  });
  return order;
}

function formatOrder(order) {
  return {
    id: order.id,
    product_id: order.productId,
    product_title: order.product_title,
    order_status: order.order_status,
    seller_id: order.sellerId,
    seller_name: userName(order.sellerId),
    seller_rating: order.seller_rating ?? 4.8,
    buyer_id: order.buyerId,
    tracking_no: order.tracking_no ?? '',
    shipping_type: order.shipping_type,
    package_size: order.package_size,
    amount: order.amount,
    created_at: order.created_at,
  };
}

export function getBuyerOrders(userId) {
  loadDb();
  return db.orders.filter((o) => o.buyerId === userId).map(formatOrder);
}

export function getSellerOrders(userId) {
  loadDb();
  return db.orders.filter((o) => o.sellerId === userId).map(formatOrder);
}

export function getOrderById(orderId) {
  loadDb();
  return db.orders.find((o) => o.id === orderId) ?? null;
}

export function getBuyerOrderBadges(userId) {
  const orders = getBuyerOrders(userId);
  const activeShipmentCount = orders.filter((o) =>
    ['packed', 'shipped', 'in_transit'].includes(o.order_status),
  ).length;
  return { activeShipmentCount };
}

export function shipOrder(sellerId, orderId, { trackingNo, shipmentStatus }) {
  loadDb();
  const order = getOrderById(orderId);
  if (!order || order.sellerId !== sellerId) return { ok: false, message: 'Sipariş bulunamadı' };
  order.tracking_no = String(trackingNo || '').trim();
  order.order_status = shipmentStatus || 'shipped';
  order.events.push({
    event_type: order.order_status,
    note: trackingNo ? `Takip no: ${trackingNo}` : 'Kargo güncellendi',
    created_at: new Date().toISOString(),
  });
  addNotification({
    userId: order.buyerId,
    title: 'Kargo güncellendi',
    message: `Sipariş #${order.id} için kargo durumu güncellendi`,
    data: { orderId: order.id },
  });
  saveDb();
  return { ok: true, message: 'Kargo bilgisi güncellendi' };
}

export function deliverOrder(sellerId, orderId) {
  loadDb();
  const order = getOrderById(orderId);
  if (!order || order.sellerId !== sellerId) return { ok: false, message: 'Sipariş bulunamadı' };
  order.order_status = 'delivered';
  order.events.push({
    event_type: 'delivered',
    note: 'Teslim edildi',
    created_at: new Date().toISOString(),
  });
  const product = getProductById(order.productId);
  if (product) product.sale_status = 'sold';
  addNotification({
    userId: order.buyerId,
    title: 'Teslim edildi',
    message: `Sipariş #${order.id} teslim edildi`,
    data: { orderId: order.id },
  });
  saveDb();
  return { ok: true, message: 'Sipariş teslim edildi olarak işaretlendi' };
}

export function requestCancel(buyerId, orderId) {
  loadDb();
  const order = getOrderById(orderId);
  if (!order || order.buyerId !== buyerId) return { ok: false, message: 'Sipariş bulunamadı' };
  order.order_status = 'cancel_requested';
  order.events.push({
    event_type: 'cancel_requested',
    note: 'İptal talebi oluşturuldu',
    created_at: new Date().toISOString(),
  });
  addNotification({
    userId: order.sellerId,
    title: 'İptal talebi',
    message: `Sipariş #${order.id} için iptal talebi var`,
    data: { orderId: order.id },
  });
  saveDb();
  return { ok: true, message: 'İptal talebi iletildi' };
}

export function requestReturn(buyerId, orderId) {
  loadDb();
  const order = getOrderById(orderId);
  if (!order || order.buyerId !== buyerId) return { ok: false, message: 'Sipariş bulunamadı' };
  order.order_status = 'return_requested';
  order.events.push({
    event_type: 'return_requested',
    note: 'İade talebi oluşturuldu',
    created_at: new Date().toISOString(),
  });
  addNotification({
    userId: order.sellerId,
    title: 'İade talebi',
    message: `Sipariş #${order.id} için iade talebi var`,
    data: { orderId: order.id },
  });
  saveDb();
  return { ok: true, message: 'İade talebi iletildi' };
}

export function getOrderTracking(orderId, userId) {
  const order = getOrderById(orderId);
  if (!order) return null;
  if (order.buyerId !== userId && order.sellerId !== userId) return null;
  return {
    order: formatOrder(order),
    events: order.events ?? [],
  };
}

export function getComments(productId) {
  loadDb();
  return db.comments
    .filter((c) => c.productId === productId)
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
    .map((c) => ({
      id: c.id,
      content: c.content,
      user_name: c.user_name,
      created_at: c.created_at,
    }));
}

export function addComment(userId, productId, content) {
  loadDb();
  const text = String(content || '').trim();
  if (!text) return { ok: false, message: 'Yorum boş olamaz' };
  const comment = {
    id: db.nextCommentId++,
    productId,
    userId,
    user_name: userName(userId),
    content: text.slice(0, 500),
    created_at: new Date().toISOString(),
  };
  db.comments.unshift(comment);
  saveDb();
  return { ok: true, comment };
}

export function getPriceInsights({ title, category, brand }) {
  loadDb();
  const needleTitle = String(title || '').trim().toLowerCase();
  const needleCategory = String(category || '').trim().toLowerCase();
  const needleBrand = String(brand || '').trim().toLowerCase();

  const similar = db.products.filter((p) => {
    if (needleBrand && String(p.brand || '').toLowerCase().includes(needleBrand)) return true;
    if (needleCategory && String(p.category || '').toLowerCase().includes(needleCategory)) return true;
    if (needleTitle && String(p.title || '').toLowerCase().includes(needleTitle.split(' ')[0] || '')) {
      return true;
    }
    return false;
  });

  const prices = similar.map((p) => Number(p.price)).filter((n) => Number.isFinite(n) && n > 0);
  if (!prices.length) {
    return { success: true, count: 0, avgPrice: null, minPrice: null, maxPrice: null };
  }
  const sum = prices.reduce((a, b) => a + b, 0);
  return {
    success: true,
    count: prices.length,
    avgPrice: Math.round(sum / prices.length),
    minPrice: Math.min(...prices),
    maxPrice: Math.max(...prices),
  };
}

export function getSellerProducts(userId) {
  loadDb();
  return db.products.filter((p) => p.sellerId === userId).map(formatProductForApi);
}

export function listProductsFormatted(filters) {
  return listProducts(filters).map(formatProductForApi);
}

export function getSellerPanelStats(userId) {
  const products = getSellerProducts(userId);
  const orders = getSellerOrders(userId);
  const activeProducts = products.filter((p) => (p.sale_status ?? 'available') === 'available').length;
  const pendingShipments = orders.filter((o) =>
    ['paid', 'packed', 'shipped', 'in_transit'].includes(o.order_status),
  ).length;
  const totalSales = orders.filter((o) => o.order_status === 'delivered').length;
  return {
    trust: {
      badge: totalSales >= 5 ? 'Altın' : totalSales >= 1 ? 'Gümüş' : 'Bronz',
      rating: 4.8,
      isVerified: true,
    },
    stats: {
      activeProducts,
      pendingShipments,
      totalSales,
      activeListings: activeProducts,
    },
  };
}
