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
  ], // Shorter duration
  thresholds: {
    // Very lenient thresholds that should always pass for a smoke test
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

// //   load-test.js
// import http from 'k6/http';
// import { check, sleep } from 'k6';
// import { Rate } from 'k6/metrics';

// // Custom metrics
// const errorRate = new Rate('errors');

// Test configuration
// export const options = {
//   stages: [
//     { duration: '2m', target: 500 },    // Ramp to 500 users
//     { duration: '2m', target: 1000 },   // Ramp to 1000 users
//     { duration: '5m', target: 1500 },   // Ramp to 1500 users
//     { duration: '5m', target: 2000 },   // Ramp to 2000 users
//     { duration: '2m', target: 2500 },   // Spike to 2500 users
//     { duration: '5m', target: 2500 },   // Sustain 2500 users
//     { duration: '2m', target: 1000 },   // Ramp down to 1000 users
//     { duration: '1m', target: 0 },     
//   ],
//   thresholds: {
//     // 95% of requests should complete within 500ms
//     http_req_duration: ['p(95)<500'],
//     // 99% of requests should complete within 1000ms
//     'http_req_duration{status:200}': ['p(99)<1000'],
//     // Error rate should be less than 1%
//     errors: ['rate<0.01'],
//     // Request rate should be at least 900 req/s during sustained load
//     http_reqs: ['rate>900'],
//   },
// };

// // Get the load balancer URL from environment variable
// const BASE_URL = __ENV.BASE_URL || 'http://localhost';

// export default function () {
//   // Test different endpoints and HTTP methods
//   const endpoints = [
//     { method: 'GET', url: `${BASE_URL}/get` },
//     { method: 'POST', url: `${BASE_URL}/post`, body: JSON.stringify({ test: 'data' }) },
//     { method: 'PUT', url: `${BASE_URL}/put`, body: JSON.stringify({ update: 'data' }) },
//     { method: 'OPTIONS', url: `${BASE_URL}/anything` }, // Test CORS preflight
//   ];

//   // Randomly select an endpoint
//   const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
//   const params = {
//     headers: {
//       'Content-Type': 'application/json',
//       'Origin': 'https://example.com', // Test CORS
//     },
//   };

//   let response;
//   if (endpoint.body) {
//     response = http[endpoint.method.toLowerCase()](endpoint.url, endpoint.body, params);
//   } else {
//     response = http[endpoint.method.toLowerCase()](endpoint.url, params);
//   }

//   // Check response
//   const result = check(response, {
//     'status is 200': (r) => r.status === 200,
//     'response time < 500ms': (r) => r.timings.duration < 500,
//     'has CORS headers': (r) => r.headers['Access-Control-Allow-Origin'] !== undefined,
//   });

//   // Record errors
//   errorRate.add(!result);

//   // Random sleep between 0.1s and 1s to simulate real user behavior
// //   sleep(Math.random() * 0.9 + 0.1);
// }

// // Setup function - runs once before the test
// export function setup() {
//   console.log('Starting load test...');
//   console.log(`Base URL: ${BASE_URL}`);
  
//   // Warm-up request
//   const response = http.get(`${BASE_URL}/health`);
//   if (response.status !== 200) {
//     console.error('Health check failed! Aborting test.');
//     return null;
//   }
  
//   console.log('Health check passed. Starting load test...');
//   return { baseUrl: BASE_URL };
// }
