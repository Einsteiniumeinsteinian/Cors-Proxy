import http from 'k6/http';
import { check, group } from 'k6';

export const options = {
  vus: 5, // Reduced load for smoke test
  stages: [
    { duration: '1m', target: 500 },    // Ramp to 500 users
    { duration: '1m', target: 1000 },   // Ramp to 1000 users
    { duration: '2m', target: 1500 },   // Ramp to 1500 users
    { duration: '5m', target: 2000 },   // Ramp to 2000 users
    { duration: '10m', target: 2500 },   // Spike to 2500 users
    { duration: '5m', target: 2500 },   // Sustain 2500 users
    { duration: '2m', target: 1000 },   // Ramp down to 1000 users
  ],
  thresholds: {
    http_reqs: ['rate>900'],
    'http_req_failed{expectedError:not_found}': ['rate<1'], // allow all for this tag
    'http_req_failed{expectedError:!not_found}': ['rate<0.1'], // apply normal threshold
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost';

export default function () {

  group('Basic Proxy Works', () => {
    const getResponse = http.get(`${BASE_URL}/get`);
  });

}

// Teardown function - runs once after the test
export function teardown(data) {
    console.log('Load test completed.');
  }
