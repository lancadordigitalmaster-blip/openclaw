module.exports = (req, res) => {
  res.status(200).json({ status: 'ok', version: '1.0', platform: 'vercel-serverless' });
};
