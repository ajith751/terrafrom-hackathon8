export const handler = async (event) => {
  const path = event.rawPath || event.path || "/";
  const method = event.requestContext?.http?.method || event.httpMethod || "GET";

  return {
    statusCode: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
    body: JSON.stringify({
      message: "OK",
      path,
      method,
      service: "healthcare-microservices",
    }),
  };
};
