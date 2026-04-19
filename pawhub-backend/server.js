//Environment Stripe API
const express = require('express');
const stripe = require('stripe')(process.env.STRIPE_SK); 
const cors = require('cors');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(express.json());

const path = require('path');

//Host the .well-known folder for Android App Links verification
app.use('/.well-known', (req, res, next) => {
  if (req.path.endsWith('assetlinks.json')) {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
  }
  next();
}, express.static(path.join(__dirname, '.well-known')));

const generateFallbackHTML = (title, type, id, downloadLink) => `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>PawHub | ${title}</title>
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f0f4f8; margin: 0; display: flex; align-items: center; justify-content: center; height: 100vh; color: #333; }
            .container { background: white; padding: 40px; border-radius: 16px; box-shadow: 0 15px 35px rgba(33, 150, 243, 0.1); text-align: center; max-width: 400px; width: 90%; border-top: 5px solid #2196F3; }
            .logo { font-size: 50px; margin-bottom: 10px; }
            h1 { font-size: 24px; margin-bottom: 10px; color: #1a237e; }
            p { color: #546e7a; line-height: 1.6; margin-bottom: 30px; font-size: 15px; }
            .btn { background-color: #2196F3; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 600; display: inline-block; transition: all 0.3s ease; box-shadow: 0 4px 12px rgba(33, 150, 243, 0.3); }
            .btn:hover { background-color: #1976D2; transform: translateY(-2px); }
            .footer { margin-top: 25px; font-size: 12px; color: #90a4ae; border-top: 1px solid #eceff1; padding-top: 15px; }
            span.highlight { color: #2196F3; font-weight: bold; background: #e3f2fd; padding: 2px 6px; border-radius: 4px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="logo">🐾</div>
            <h1>${title}</h1>
            <p>You're viewing ${type} <span class="highlight">#${id}</span>. <br> Open our mobile app for the full experience.</p>
            <a href="${downloadLink}" class="btn">Get the App</a>
            <div class="footer">If the app is installed, it should launch automatically.<br><strong>PawHub Alpha</strong></div>
        </div>
        <script>
            window.onload = function() {
                setTimeout(function() {
                    window.location.href = "pawhub://${type}/${id}";
                }, 800);
            };
        </script>
    </body>
    </html>
`;


const GITHUB_LINK = "https://github.com/AlexHong04/pawhub";

// Post Route
app.get('/post/:id', (req, res) => {
  try {
    const postId = req.params.id;
    if (!postId || postId === 'undefined') throw new Error("Post ID is missing.");
    res.send(generateFallbackHTML("View Post", "post", postId, GITHUB_LINK));
  } catch (err) {
    res.status(400).send(`<h1 style="font-family:sans-serif; text-align:center; color:#d32f2f; margin-top:50px;">⚠️ Post Error: ${err.message}</h1>`);
  }
});

// Event Route
app.get('/event/:id', (req, res) => {
  try {
    const eventId = req.params.id;

    // Validate Event ID (e.g., must not be undefined or empty)
    if (!eventId || eventId === 'undefined') {
      throw new Error("Invalid or missing Event ID.");
    }

    res.send(generateFallbackHTML("View Event", "event", eventId, GITHUB_LINK));
  } catch (err) {
    console.error("Event route error:", err.message);
    res.status(400).send(`
      <div style="text-align:center; padding-top:100px; font-family:sans-serif; color:#d32f2f;">
        <h1>⚠️ Event Link Error</h1>
        <p>${err.message}</p>
        <p style="color:#777;">Please ensure the link is correct or open the app manually.</p>
        <a href="${GITHUB_LINK}" style="color:#2196F3; text-decoration:none; font-weight:bold;">Download APK</a>
      </div>
    `);
  }
});

/*   res.send(`
     <!DOCTYPE html>
     <html lang="en">
     <head>
         <meta charset="UTF-8">
         <meta name="viewport" content="width=device-width, initial-scale=1.0">
         <title>PawHub | View Post</title>
         <style>
             body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f0f4f8; margin: 0; display: flex; align-items: center; justify-content: center; height: 100vh; color: #333; }
             .container { background: white; padding: 40px; border-radius: 16px; box-shadow: 0 15px 35px rgba(33, 150, 243, 0.1); text-align: center; max-width: 400px; width: 90%; border-top: 5px solid #2196F3; }
             .logo { font-size: 50px; margin-bottom: 10px; filter: drop-shadow(0 2px 4px rgba(0,0,0,0.1)); }
             h1 { font-size: 24px; margin-bottom: 10px; color: #1a237e; }
             p { color: #546e7a; line-height: 1.6; margin-bottom: 30px; font-size: 15px; }
             .btn { background-color: #2196F3; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 600; display: inline-block; transition: all 0.3s ease; box-shadow: 0 4px 12px rgba(33, 150, 243, 0.3); }
             .btn:hover { background-color: #1976D2; transform: translateY(-2px); }
             .btn:active { transform: translateY(0); }
             .footer { margin-top: 25px; font-size: 12px; color: #90a4ae; border-top: 1px solid #eceff1; padding-top: 15px; }
             span.post-id { color: #2196F3; font-weight: bold; background: #e3f2fd; padding: 2px 6px; border-radius: 4px; }
         </style>
     </head>
     <body>
         <div class="container">
             <div class="logo">🐾</div>
             <h1>Continue to PawHub</h1>
             <p>You're viewing post <span class="post-id">#${postId}</span>. <br> Open our mobile app for the full experience.</p>

             <a href="${downloadLink}" class="btn">Get the App</a>

             <div class="footer">
                 If the app is installed, it should launch automatically.<br>
                 <strong>PawHub Alpha v1.0</strong>
             </div>
         </div>

         <script>
             // Automatic redirect attempt
             window.onload = function() {
                 setTimeout(function() {
                     window.location.href = "pawhub://post/${postId}";
                 }, 800);
             };
         </script>
     </body>
     </html>
   `);
 });
 */

//Environment Email
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER, 
    pass: process.env.EMAIL_PASS  
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
    from: '"PawHub Team" <no-reply.pawhub@hongjin.site>',
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