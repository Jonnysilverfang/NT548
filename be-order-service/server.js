const express = require("express");
const cors = require("cors");

const app = express();
const PORT = Number(process.env.PORT || 5003);

const orders = [
  { order_id: "ORD-9021", customer: "Nguyễn Văn A", total: 49.99, status: "COMPLETED" },
  { order_id: "ORD-9022", customer: "Trần Thị B", total: 118.5, status: "PROCESSING" },
  { order_id: "ORD-9023", customer: "Lê Văn C", total: 35.0, status: "COMPLETED" },
];

app.disable("x-powered-by");
app.use(cors());
app.use(express.json({ limit: "32kb" }));

app.get(["/health", "/api/orders/health"], (_req, res) => {
  res.status(200).json({ status: "healthy", service: "order-service", port: PORT });
});

app.get("/api/orders", (_req, res) => {
  res.status(200).json(orders);
});

app.get("/api/orders/:orderId", (req, res) => {
  const order = orders.find((item) => item.order_id === req.params.orderId);
  if (!order) return res.status(404).json({ error: "NOT_FOUND", message: "Không tìm thấy đơn hàng." });
  return res.status(200).json(order);
});

app.use((_req, res) => {
  res.status(404).json({ error: "NOT_FOUND", message: "Endpoint không tồn tại." });
});

app.use((err, _req, res, _next) => {
  console.error("[ORDER] Unhandled error:", err);
  res.status(500).json({ error: "INTERNAL_ERROR", message: "Dịch vụ đơn hàng gặp lỗi." });
});

app.listen(PORT, "0.0.0.0", () => console.log(`[ORDER] Listening on port ${PORT}`));
