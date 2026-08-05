// © 2024-2026 Бутаев Алексей Юрьевич. All rights reserved. PROPRIETARY AND CONFIDENTIAL.
/**
 * Zod Validation Plugin for Fastify
 *
 * Intercepts route schemas that use Zod objects directly (which Fastify cannot
 * natively compile) and replaces them with a preHandler validation hook.
 * This allows routes to declare `schema: { body: myZodSchema }` without
 * causing "schema is invalid: data/required must be array" errors.
 */

import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { ZodSchema, ZodError } from 'zod';

function isZodSchema(obj: unknown): obj is ZodSchema {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    typeof (obj as any).safeParse === 'function' &&
    typeof (obj as any).parse === 'function'
  );
}

function zodPreHandler(schema: ZodSchema) {
  return async (request: FastifyRequest, _reply: FastifyReply) => {
    const result = schema.safeParse(request.body);
    if (!result.success) {
      const firstIssue = result.error.issues[0];
      const message = firstIssue?.message || 'Validation error';
      const reply = _reply;
      return reply.code(400).send({
        statusCode: 400,
        error: 'Bad Request',
        message,
      });
    }
    // Replace body with parsed/transformed data
    request.body = result.data;
  };
}

export async function zodValidationPlugin(fastify: FastifyInstance) {
  fastify.addHook('onRoute', (routeOptions) => {
    if (!routeOptions.schema) return;

    // Check body schema
    if (routeOptions.schema.body && isZodSchema(routeOptions.schema.body)) {
      const schema = routeOptions.schema.body as ZodSchema;
      // Remove the Zod schema so Fastify doesn't try to compile it
      delete routeOptions.schema.body;

      const handler = zodPreHandler(schema);
      const existing = routeOptions.preHandler;
      if (Array.isArray(existing)) {
        routeOptions.preHandler = [...existing, handler];
      } else if (typeof existing === 'function') {
        routeOptions.preHandler = [existing, handler];
      } else {
        routeOptions.preHandler = [handler];
      }
    }

    // Check querystring schema
    if (routeOptions.schema.querystring && isZodSchema(routeOptions.schema.querystring)) {
      const schema = routeOptions.schema.querystring as ZodSchema;
      delete routeOptions.schema.querystring;

      const handler = async (request: FastifyRequest, _reply: FastifyReply) => {
        const result = schema.safeParse(request.query);
        if (!result.success) {
          const firstIssue = result.error.issues[0];
          return _reply.code(400).send({
            statusCode: 400,
            error: 'Bad Request',
            message: firstIssue?.message || 'Validation error',
          });
        }
        // Replace query with parsed data
        (request as any).query = result.data;
      };

      const existing = routeOptions.preHandler;
      if (Array.isArray(existing)) {
        routeOptions.preHandler = [...existing, handler];
      } else if (typeof existing === 'function') {
        routeOptions.preHandler = [existing, handler];
      } else {
        routeOptions.preHandler = [handler];
      }
    }
  });
}
