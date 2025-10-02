interface LoadingComponentProps {
  title: string;
  text?: string;
}

const Loading: React.FC<LoadingComponentProps> = ({ title, text }) => {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gray-50 p-8">
      <div className="text-center space-y-14">
        {/* Loading Animation */}
        <div className="relative">
          <div className="absolute my-auto mx-auto w-16 h-16 inset-0 border-4 border-primary-200 border-t-primary-500 rounded-full animate-spin"></div>
        </div>

        <div>
          {title ? <h2 className="text-2xl font-bold text-gray-800 mb-2">{title}</h2> : null}
          {text ? <p className="text-gray-600">{text}</p> : null}
        </div>
      </div>
    </div>
  );
};

export default Loading;
