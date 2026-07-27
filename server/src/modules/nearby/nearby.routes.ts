import { FastifyInstance } from 'fastify';

export async function nearbyRoutes(fastify: FastifyInstance) {
  const { prisma, redis } = fastify;

  // GET /nearby — Пользователи рядом
  fastify.get('/', async (request, reply) => {
    const userId = request.userId!;
    const { lat, lng, radius = '1000' } = request.query as {
      lat?: string;
      lng?: string;
      radius?: string;
    };

    if (!lat || !lng) {
      return reply.code(400).send({ message: 'Укажите lat и lng' });
    }

    const userLat = parseFloat(lat);
    const userLng = parseFloat(lng);
    const radiusMeters = parseInt(radius);

    // Сохраняем позицию пользователя (временно, не персистентно!)
    await redis.set(
      `nearby:${userId}`,
      JSON.stringify({ lat: userLat, lng: userLng, updatedAt: Date.now() }),
      'EX',
      300, // 5 минут TTL
    );

    // Находим пользователей поблизости из Redis
    const nearbyKeys = await redis.keys('nearby:*');
    const nearby = [];

    for (const key of nearbyKeys) {
      const uid = key.replace('nearby:', '');
      if (uid === userId) continue;

      const data = await redis.get(key);
      if (!data) continue;

      const pos = JSON.parse(data);
      const distance = _haversineDistance(userLat, userLng, pos.lat, pos.lng);

      if (distance <= radiusMeters) {
        const user = await prisma.user.findUnique({
          where: { id: uid, status: 'ACTIVE' },
          select: { id: true, displayName: true, avatarUrl: true },
        });

        if (user) {
          nearby.push({
            user_id: user.id,
            display_name: user.displayName,
            avatar_url: user.avatarUrl,
            distance: _formatDistance(distance),
          });
        }
      }
    }

    // Сортируем по расстоянию
    nearby.sort((a, b) => {
      const da = parseFloat(a.distance.replace(/[^\d.]/g, ''));
      const db = parseFloat(b.distance.replace(/[^\d.]/g, ''));
      return da - db;
    });

    return reply.send({ data: nearby });
  });
}

// Формула гаверсинуса для расчёта расстояния
function _haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000; // Радиус Земли в метрах
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function _formatDistance(meters: number): string {
  if (meters < 100) return `${Math.round(meters)} м`;
  if (meters < 1000) return `${Math.round(meters / 100) * 100} м`;
  return `${(meters / 1000).toFixed(1)} км`;
}
