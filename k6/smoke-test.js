import http from 'k6/http';
import { check, group } from 'k6';

export const options = {
  vus: 5, // Reduced load for smoke test
  duration: '30s', // Shorter duration
  thresholds: {
    http_req_duration: ['p(95)<500'], // 2 seconds is very generous
    'http_req_failed{expectedError:not_found}': ['rate<1'], // allow all for this tag
    'http_req_failed{expectedError:!not_found}': ['rate<0.1'], // apply normal threshold
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost';

export default function () {
  group('Basic Health Check', () => {
    const response = http.get(`${BASE_URL}/health`);
    check(response, {
      'health endpoint is reachable': (r) => r.status === 200,
      'health returns OK': (r) => r.body.includes('OK'),
    });
  });

  group('CORS Preflight Works', () => {
    const preflightResponse = http.options(`${BASE_URL}/get`, null, {
      headers: {
        'Origin': 'https://example.com',
        'Access-Control-Request-Method': 'GET',
      },
    });

    check(preflightResponse, {
      'preflight request succeeds': (r) => r.status === 204,
      'preflight has allow-origin': (r) => r.headers['Access-Control-Allow-Origin'] !== undefined,
    });
  });

  group('Basic Proxy Works', () => {
    const getResponse = http.get(`${BASE_URL}/get`);
    check(getResponse, {
      'proxy request succeeds': (r) => r.status === 200,
      'response has CORS headers': (r) => r.headers['Access-Control-Allow-Origin'] !== undefined,
      'response looks like JSON': (r) => {
        try {
          JSON.parse(r.body);
          return true;
        } catch (e) {
          return false;
        }
      },
    });
  });

  group('Error Handling Works', () => {
    const notFoundResponse = http.get(`${BASE_URL}/this-definitely-does-not-exist`);
    check(notFoundResponse, {
      'returns some error status': (r) => r.status >= 400,
      'error response has CORS': (r) => r.headers['Access-Control-Allow-Origin'] !== undefined,
    });
  });
}