import { APIGatewayProxyHandler } from 'aws-lambda';
import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

const ses = new SESClient({ region: 'eu-west-1' });

interface ContactFormRequest {
  email: string;
  message: string;
}

export const handler: APIGatewayProxyHandler = async (event) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };

  // Handle CORS preflight
  if (event.httpMethod === 'OPTIONS') {
    return {
      statusCode: 200,
      headers: corsHeaders,
      body: '',
    };
  }

  try {
    if (!event.body) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Missing request body' }),
      };
    }

    const body: ContactFormRequest = JSON.parse(event.body);
    const { email, message } = body;

    if (!email || !message) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Email and message are required' }),
      };
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return {
        statusCode: 400,
        headers: corsHeaders,
        body: JSON.stringify({ error: 'Invalid email format' }),
      };
    }

    // Send email via SES
    const toAddress = process.env.CONTACT_EMAIL || 'jasondgoldsmith@gmail.com';

    const command = new SendEmailCommand({
      Source: toAddress, // Must be a verified SES email
      Destination: {
        ToAddresses: [toAddress],
      },
      Message: {
        Subject: {
          Data: `Nugget Contact Form: Message from ${email}`,
          Charset: 'UTF-8',
        },
        Body: {
          Text: {
            Data: `From: ${email}\n\nMessage:\n${message}`,
            Charset: 'UTF-8',
          },
          Html: {
            Data: `
              <h2>New Contact Form Submission</h2>
              <p><strong>From:</strong> ${email}</p>
              <hr>
              <p><strong>Message:</strong></p>
              <p>${message.replace(/\n/g, '<br>')}</p>
            `,
            Charset: 'UTF-8',
          },
        },
      },
      ReplyToAddresses: [email],
    });

    await ses.send(command);

    return {
      statusCode: 200,
      headers: corsHeaders,
      body: JSON.stringify({ success: true, message: 'Message sent successfully' }),
    };
  } catch (error) {
    console.error('Contact form error:', error);
    return {
      statusCode: 500,
      headers: corsHeaders,
      body: JSON.stringify({ error: 'Failed to send message' }),
    };
  }
};
