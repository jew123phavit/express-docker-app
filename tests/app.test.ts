import request from 'supertest'
import express from 'express'

const app = express()
app.get('/api/hello', (_, res) => res.json({ message: 'Hello from Express API!' }))

test('GET /api/hello', async () => {
  const res = await request(app).get('/api/hello')
  expect(res.statusCode).toBe(200)
  expect(res.body.message).toBe('Hello from Express API!')
})