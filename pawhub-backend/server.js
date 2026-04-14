//Environment Stripe API
const express = require('express');
const stripe = require('stripe')('sk_test_51TL6AwRwursbSQXL4gGL7V8jwvegK0OMURFZ5YgiXnEv8kVAwo7Z96GEH1sfZzkcChNmeKih89QMkck3R2okkIXQ00dcOekXUJ');
const cors = require('cors');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(express.json());

//Environment Email
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'unknowsuser050@gmail.com',
    pass: 'eoty cfpl wsiw absc'    // Google App Password
  }
});

// Stripe API
app.post('/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency } = req.body;
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency,
    });
    res.json({ clientSecret: paymentIntent.client_secret });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});

//Email
//app.post('/send-donation-email', async (req, res) => {
//  const { email, amount, userName } = req.body;
//
//  const mailOptions = {
//    from: '"PawHub Team" <yourpawhub@gmail.com>',
//    to: email,
//    subject: 'Thank you for your kindness! 🐾',
//    html: `
//      <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee;">
//        <h2 style="color: #2196F3;">Hi ${userName},</h2>
//        <p>Your donation of <strong>RM ${amount}</strong> has been received successfully!</p>
//        <p>This contribution will go a long way in helping our shelter animals find their forever homes.</p>
//        <hr>
//        <p style="font-size: 12px; color: #888;">Thank you for being a hero for the furry friends at PawHub.</p>
//      </div>
//    `
//  };
//
//  try {
//    await transporter.sendMail(mailOptions);
//    res.json({ success: true, message: "Email sent!" });
//  } catch (e) {
//    console.error("Email Error:", e);
//    res.status(500).json({ error: "Failed to send email" });
//  }
//});

app.post('/send-general-email', async (req, res) => {
  const { email, subject, htmlContent } = req.body;

  if (!email || !subject || !htmlContent) {
    return res.status(400).json({ error: "Missing required fields: email, subject, or htmlContent" });
  }

  const mailOptions = {
    from: '"PawHub Team" <unknowsuser050@gmail.com>',
    to: email,
    subject: subject,
    html: htmlContent
  };

  try {
    await transporter.sendMail(mailOptions);
    res.json({ success: true, message: "Email sent successfully!" });
  } catch (e) {
    console.error("Email API Error:", e);
    res.status(500).json({ error: "Failed to send email" });
  }
});

app.listen(3000, () => {
  console.log('Secure Stripe Backend is running on port 3000');
});